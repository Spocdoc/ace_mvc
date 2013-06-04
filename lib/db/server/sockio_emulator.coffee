mongodb = require 'mongodb'
Callback = require './callback'
OJSON = require '../../ojson'

# emulates the *client's* sock.io access
class SockioEmulator
  constructor: (@db, Mediator) ->
    @mediator = new Mediator @db,
      id: 0

  emit: (verb, data, cb) ->
    switch verb
      when 'create'
        @mediator.create data['c'], OJSON.fromOJSON(data['v']), new Callback cb

      when 'read'
        @mediator.read data['c'], data['i'], data['e'], new Callback cb

      when 'update'
        @mediator.update data['c'], data['i'], data['e'], OJSON.fromOJSON(data['d']), new Callback cb

      when 'delete'
        @mediator.delete data['c'], data['i'], new Callback cb

      when 'subscribe', 'unsubscribe'
        cb()

  on: (event, fn) -> # noop

module.exports = SockioEmulator
