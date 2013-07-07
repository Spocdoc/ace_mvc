mongodb = require 'mongodb'
Callback = require './callback'
OJSON = require '../../../utils/ojson'
{include} = require '../../../utils/mixin'

class Emitter
  include @, require '../../../utils/events/emitter'

# emulates the *client's* sock.io access
class SockioEmulator
  constructor: (@db, Mediator) ->
    @emitter = new Emitter
    @mediator = new Mediator @db,
      id: 0
      emit: (event, data) =>
        @emitter.emit event, data


  emit: (verb, data, cb) ->
    switch verb
      when 'create'
        @mediator.create data['c'], OJSON.fromOJSON(data['v']), new Callback cb

      when 'read'
        @mediator.read data['c'], data['i'], data['e'], new Callback(cb), data['q'], data['s'], data['l'],

      when 'update'
        @mediator.update data['c'], data['i'], data['e'], OJSON.fromOJSON(data['d']), new Callback cb

      when 'delete'
        @mediator.delete data['c'], data['i'], new Callback cb

      when 'run'
        @mediator.run data['c'], data['i'], data['e'], data['m'], OJSON.fromOJSON(data['a']), new Callback cb

  on: (event, fn) ->
    @emitter.on event, fn

module.exports = SockioEmulator