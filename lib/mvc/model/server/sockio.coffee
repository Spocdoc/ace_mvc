OJSON = require '../../../utils/ojson'
sockio = require("socket.io")
redis = require 'redis'
RedisStore = require 'socket.io/lib/stores/redis'
Db = require './db'
callback = require './callback'
debug = global.debug 'ace:error'

# called with this = sock

module.exports = (db, redisInfo, server, Mediator) ->

  io = sockio.listen(server)
  io.set 'store', new RedisStore
    redis: redis
    redisPub: redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    redisSub: redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    redisClient: redis.createClient redisInfo.host, redisInfo.port, redisInfo.options

  io.set 'browser client', false

  io.configure 'development', ->
    io.set 'log level', 3
    io.set 'transports', [
      'websocket'
      'flashsocket'
      'htmlfile'
      'xhr-polling'
    ]

  io.configure 'production', ->
    io.set 'log level', 1
    io.set 'transports', [
      'websocket'
      'flashsocket'
      'htmlfile'
      'xhr-polling'
    ]

  io.on 'connection', (sock) ->
    sock.mediator = mediator = new Mediator db, sock
    cookiesQueue = null

    sock.on 'cookies', ->
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

  io
