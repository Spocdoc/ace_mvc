mongodb = require 'mongodb'
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
      emit: (event, data) => @emitter.emit event, data

  emit: (verb) -> @mediator[verb].apply @mediator, arguments
  on: (event, fn) -> @emitter.on event, fn

module.exports = SockioEmulator
