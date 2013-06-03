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

  clone.register ObjectID, (other) -> new ObjectID(other.toString())
  OJSON.register 'ObjectID': ObjectID

  OJSON.register 'DBRef': DBRef
  extend DBRef, OJSON.copyKeys
  diff.register DBRef, diffObj, patchObj
  clone.register DBRef, (other) -> new DBRef(other.namespace, other.oid)

  db = new Db(config, config.redis)

  # for server-side rendering
  global.io =
    connect: (path) ->
      new SockioEmulator(db, (config.mediator && require config.mediator) || Mediator)

  s = sockio(db, config.redis, app.settings.server, (config.mediator && require config.mediator) || Mediator)



