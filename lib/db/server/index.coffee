SockioEmulator = require './sockio_emulator'
sockio = require './sockio'
Db = require './db'
clone = require '../../clone'
ObjectID = global.mongo.ObjectID
OJSON = require '../../ojson'

db = undefined
s = undefined

module.exports = (app, config) ->

  clone.register ObjectID, (other) -> new ObjectID(other.toString())
  OJSON.register 'ObjectID': ObjectID

  db = new Db(config, config.redis)

  # for server-side rendering
  global.io =
    connect: (path) ->
      new SockioEmulator(db)

  s = sockio(db, config.redis, app.settings.server)



