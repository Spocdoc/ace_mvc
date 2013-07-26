SockioEmulator = require './sockio_emulator'
sockio = require './sockio'
Db = require './db'
clone = require '../../../utils/clone'
ObjectID = global.mongo.ObjectID
DBRef = global.mongo.DBRef
OJSON = require '../../../utils/ojson'
diff = require '../../../utils/diff'
MediatorServer = require './mediator_server'
MediatorClient = require './mediator_client'
emptyFunction = ->

db = undefined
s = undefined

module.exports = (config, app) ->

  OJSON.register 'ObjectID': ObjectID
  clone.register ObjectID, (other) -> new ObjectID(other.toString())

  OJSON.register 'DBRef': DBRef
  # override mongodb's implementation because their "$id" value isn't a JSON element -- it's an ObjectID!
  DBRef.prototype.toJSON = ->
    "$ref": @namespace
    "$id": OJSON.toOJSON @oid
  DBRef.fromJSON = (obj) ->
    new DBRef obj['$ref'], obj['$id']
  clone.register DBRef, (other) -> new DBRef(other.namespace, other.oid)

  diff.register DBRef,
    ((from, to, options) ->
      unless to instanceof DBRef
        coll = to.coll
        id = to.id?.toString()
        to = {namespace: coll, oid: id} if id and typeof coll is 'string'

      return false if to.namespace is from.namespace and to.oid is from.oid
      [{'o':1, 'v':to}]
    ), ((obj, diff, options) -> obj['v'])

  db = new Db(config, config.redis)

  if makeMediator = config.mediator_factory && require(config.mediator_factory)
    MediatorClient = makeMediator MediatorClient
    MediatorServer = makeMediator MediatorServer

  # for server-side rendering
  global.io =
    connect: (path) ->
      new SockioEmulator db, MediatorServer

  # socket remote clients connect to
  s = sockio db, config.redis, app.settings.server, MediatorClient

