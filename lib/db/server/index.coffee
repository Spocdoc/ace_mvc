global.mongo = require 'mongodb' # for ObjectID & other types
SockioEmulator = require './sockio_emulator'
sockio = require './sockio'
Db = require './db'

db = undefined
s = undefined

module.exports = (app, config) ->
  db = new Db(config, config.redis)

  # for server-side rendering
  global.io =
    connect: (path) ->
      new SockioEmulator(db)

  s = sockio(db, config.redis, app.settings.server)

