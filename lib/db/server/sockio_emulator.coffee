mongodb = require 'mongodb'

class SockioEmulator
  constructor: (@db) ->

  emit: (verb, data, cb) ->
    switch verb
      when 'create'
        @db.create 0, data['c'], OJSON.fromOJSON(data['v']), cb

      # when the server is rendering, there's no subscription. full documents
      # are always returned
      when 'subscribe', 'read'
        @db.read 0, data['c'], data['i'], data['e'], cb

      when 'update'
        @db.update 0, data['c'], data['i'], data['e'], OJSON.fromOJSON(data['d']), cb

      when 'delete'
        @db.delete 0, data['c'], data['i'], cb

  on: (event, fn) -> # noop

module.exports = SockioEmulator
