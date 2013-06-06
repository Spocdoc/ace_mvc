{include, extend} = require '../../mixin'
SockioEmulator = require './sockio_emulator'
sockio = require './sockio'
Db = require './db'
clone = require '../../clone'
ObjectID = global.mongo.ObjectID
DBRef = global.mongo.DBRef
OJSON = require '../../ojson'
diff = require '../../diff'
{'diff': diffObj, 'patch': patchObj} = require('../../diff/object')
Mediator = require './mediator'

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

  # for server-side rendering
  global.io =
    connect: (path) ->
      new SockioEmulator(db, (config.mediator && require config.mediator) || Mediator)

  s = sockio(db, config.redis, app.settings.server, (config.mediator && require config.mediator) || Mediator)



