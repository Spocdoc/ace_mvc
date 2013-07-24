mongodb = require 'mongodb'
callback = require './callback'
OJSON = require '../../../utils/ojson'
{include} = require '../../../utils/mixin'
debug = global.debug 'ace:error'

class Emitter
  include @, require '../../../utils/events/emitter'

# emulates the *client's* sock.io access
class SockioEmulator
  constructor: (@db, Mediator) ->
    @emitter = new Emitter
    @mediator = new Mediator @db,
      id: 0
      emit: (event, data) => @emitter.emit event, data

    @pending = 0
    @_idleCallbacks = []

  emit: (name) ->
    Callback = callback[name.charAt(0).toUpperCase() + name[1..]]

    args = arguments[1..]

    for argFn,iFn in args when typeof arg is 'function'
      ++@pending
      args[iFn] = new Callback =>
        try
          argFn.apply null, arguments
        catch _error
          debug _error?.stack
        finally
          unless --@pending
            cb() for cb in @_idleCallbacks
      break

    for arg, i in args when typeof arg is 'object'
      args[i] = OJSON.fromOJSON arg

    @mediator[name].apply @mediator, args

  on: (event, fn) -> @emitter.on event, fn

  onIdle: (cb) ->
    unless @pending
      cb()
    else
      @_idleCallbacks.push cb
    return

module.exports = SockioEmulator
