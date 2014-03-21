# takes an object returned from io.connect and wraps it to pass on, once and
# emit events serializing/deserializing with OJSON

OJSON = require 'ojson'
Outlet = require 'outlet'
AceError = require '../error'
Reject = require '../error/reject'

receive = (fn, withError) ->
  ->
    arguments[i] = OJSON.fromOJSON arg for arg, i in arguments when typeof arg is 'object'

    if withError
      # arguments[0] is always the error -- ensure that it's an AceError type
      if arguments[0]? and !(arguments[0] instanceof AceError)
        arguments[0] = new Reject 'UNKNOWN'

    # if there's a completion function, calling it should serialize the outbound arguments
    # and the first argument is always an error
    for argFn, iFn in arguments when typeof argFn is 'function'
      arguments[iFn] = ->
        if arguments[0]? and !(arguments[0] instanceof AceError)
          arguments[0] = new Reject 'UNKNOWN'

        # convert outbound objects to OJSON representation
        arguments[i] = OJSON.toOJSON arg for arg, i in arguments when typeof arg is 'object'

        argFn.apply null, arguments

      break

    Outlet.openBlock()
    try
      fn.apply null, arguments
    finally
      Outlet.closeBlock()

module.exports = class OjsonSocket
  constructor: (@sock) ->
    @id = @sock.id

  on: (name, fn) ->
    @sock.on name, receive(fn)

  once: (name, fn) ->
    @sock.once name, receive(fn)

  emit: ->
    # convert outbound objects to OJSON representation
    arguments[i] = OJSON.toOJSON arg for arg, i in arguments when typeof arg is 'object'

    # if there's a function, its inbound arguments should be deserialized
    for argFn, iFn in arguments when typeof argFn is 'function'
      arguments[iFn] = receive(argFn, true)
      break

    @sock.emit.apply @sock, arguments
