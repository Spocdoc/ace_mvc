OJSON = require 'ojson'
AceError = require '../error'
Reject = require '../error/reject'

module.exports = (sock) ->
  # sock.mediator = mediator = new Mediator db, sock
  mediator = sock.mediator
  cookiesQueue = null

  sock.on 'cookies', ->
    return if cookiesQueue

    args = Array.apply null, arguments

    # change the function so it invokes the queue afterwards
    for argFn,iFn in args when typeof argFn is 'function'
      cookiesQueue = []

      args[iFn] = ->
        try
          argFn.apply null, arguments
        catch _error
          debug _error?.stack
        finally
          queue = cookiesQueue; cookiesQueue = null
          mediator[name].apply mediator, args for {name,args} in queue

      break

    mediator['cookies'].apply mediator, args

  for name in ['disconnect', 'create', 'read', 'update', 'delete', 'run', 'distinct']
    do (name) ->
      sock.on name, ->

        args = Array.apply null, arguments

        # store in queue if received cookies, else execute immediately
        if cookiesQueue
          cookiesQueue.push {name,args}
        else
          mediator[name].apply mediator, args

  return

