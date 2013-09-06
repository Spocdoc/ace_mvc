mongodb = require 'mongo-fork'
callback = require '../db/callback'
OJSON = require 'ojson'
{include} = require 'lodash-fork'
debug = global.debug 'ace:error'

class Emitter
  id: 0
  include @, require 'events-fork/emitter'

# emulates the *client's* sock.io access
module.exports = class SockioEmulator
  constructor: (@db, Mediator) ->
    @serverSock = new Emitter
    @mediator = new Mediator @db, @serverSock

    @pending = 0
    @_idleCallbacks = []

  _unpend: ->
    unless --@pending
      cb() for cb in @_idleCallbacks.splice(0)

  _runMediator: (setPending, name, args) ->
    try
      @mediator[name].apply @mediator, args
    catch _error
      debug _error?.stack
      @_unpend() if setPending
    return

  emit: (name, args...) ->
    Callback = callback[name.charAt(0).toUpperCase() + name[1..]]
    cookies = name is 'cookies'
    setPending = false

    for arg, i in args when typeof arg is 'object'
      args[i] = OJSON.fromOJSON arg

    # separate loop to avoid having to create a do wrap just for the arg closure
    for argFn,i in args when typeof argFn is 'function'
      setPending = ++@pending
      @_cookiesQueue = [] if cookies

      args[i] = new Callback =>
        try
          argFn.apply null, arguments
        catch _error
          debug _error?.stack
        finally
          if cookies
            queue = @_cookiesQueue; @_cookiesQueue = null
            @_runMediator.apply this, a for a in queue
          @_unpend()
      break

    if !cookies and queue = @_cookiesQueue
      queue.push [setPending, name, args]
    else
      @_runMediator setPending, name, args


  on: (event, fn) -> @serverSock.on event, fn

  onIdle: (cb) ->
    unless @pending
      cb()
    else
      @_idleCallbacks.push cb
    return
