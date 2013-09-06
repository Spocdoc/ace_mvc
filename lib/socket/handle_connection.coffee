callback = require '../db/callback'
OJSON = require 'ojson'

module.exports = (sock) ->
  # sock.mediator = mediator = new Mediator db, sock
  mediator = sock.mediator
  cookiesQueue = null

  sock.on 'cookies', ->
    return if cookiesQueue

    args = Array.apply null, arguments

    for arg, i in args when typeof arg is 'object'
      args[i] = OJSON.fromOJSON arg

    for argFn,iFn in args when typeof argFn is 'function'
      cookiesQueue = []

      args[iFn] = new callback.Cookies ->
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
    Callback = callback[name.charAt(0).toUpperCase() + name[1..]]
    do (name, Callback) ->
      sock.on name, ->
        args = Array.apply null, arguments
        for arg,i in args
          switch typeof arg
            when 'object' then args[i] = OJSON.fromOJSON arg
            when 'function' then args[i] = new Callback arg
        if cookiesQueue
          cookiesQueue.push {name,args}
        else
          mediator[name].apply mediator, args

  return

