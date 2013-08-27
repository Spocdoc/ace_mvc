mongodb = require 'mongodb'
callback = require './callback'
OJSON = require '../../../utils/ojson'
{include} = require '../../../utils/mixin'
debug = global.debug 'ace:error'

class Emitter
  id: 0
  include @, require '../../../utils/events/emitter'

# emulates the *client's* sock.io access
module.exports = class SockioEmulator
  constructor: (@db, Mediator) ->
    @serverSock = new Emitter
    @mediator = new Mediator @db, @serverSock

    @pending = 0
    @_idleCallbacks = []

  emit: (name, args...) ->
    Callback = callback[name.charAt(0).toUpperCase() + name[1..]]
    cookies = name is 'cookies'

    for arg, i in args when typeof arg is 'object'
      args[i] = OJSON.fromOJSON arg

    # separate loop to avoid having to create a do wrap just for the arg closure
    for argFn,i in args when typeof argFn is 'function'
      ++@pending
      @_cookiesQueue = [] if cookies

      args[i] = new Callback =>
        try
          argFn.apply null, arguments
        catch _error
          debug _error?.stack
        finally
          if cookies
            queue = @_cookiesQueue; @_cookiesQueue = null
            @mediator[name].apply @mediator, args for {name,args} in queue

          unless --@pending
            cb() for cb in @_idleCallbacks.splice(0)
      break

    if !cookies and queue = @_cookiesQueue
      queue.push {name, args}
    else
      @mediator[name].apply @mediator, args

  on: (event, fn) -> @serverSock.on event, fn

  onIdle: (cb) ->
    unless @pending
      cb()
    else
      @_idleCallbacks.push cb
    return
