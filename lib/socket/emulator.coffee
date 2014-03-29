mongodb = require 'mongo-fork'
OJSON = require 'ojson'
{include} = require 'lodash-fork'
debugError = global.debug 'ace:error'
debug = global.debug 'ace:sock'
Outlet = require 'outlet'
AceError = require '../error'
Reject = require '../error/reject'

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
      debugError _error?.stack
      @_unpend() if setPending
    return

  # function pretends to receive the emitted content over the wire
  emit: (name, args...) ->
    cookies = name is 'cookies'
    setPending = false

    for argFn,i in args when typeof argFn is 'function'
      setPending = ++@pending
      @_cookiesQueue = [] if cookies

      args[i] = =>
        try
          # ensure the first argument is an AceError
          if arguments[0]? and !(arguments[0] instanceof AceError)
            arguments[0] = new Reject 'UNKNOWN'

          Outlet.openBlock()
          argFn.apply null, arguments
        catch _error
          debugError _error?.stack
        finally
          Outlet.closeBlock()
          if cookies
            queue = @_cookiesQueue; @_cookiesQueue = null
            @_runMediator.apply this, a for a in queue
          @_unpend()
      break

    if !cookies and queue = @_cookiesQueue
      queue.push [setPending, name, args]
    else
      @_runMediator setPending, name, args

  on: (event, fn) -> @serverSock.on event, Outlet.block fn

  onIdle: (cb) ->
    unless @pending
      cb()
    else
      @_idleCallbacks.push cb
    return

