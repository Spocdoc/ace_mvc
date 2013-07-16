OJSON = require '../../../utils/ojson'
sockio = require("socket.io")
redis = require 'redis'
RedisStore = require 'socket.io/lib/stores/redis'
Db = require './db'
callback = require './callback'

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
    for name of ['disconnect', 'cookies', 'create', 'read', 'update', 'delete', 'run']
      Callback = callback[a.charAt(0).toUpperCase() + a[1..]]
      do (name, Callback) ->
        sock.on name, ->
          for arg,i in arguments
            switch typeof arg
              when 'object' then arguments[i] = OJSON.fromOJSON arg
              when 'function' then arguments[i] = new Callback arguments[i]
          mediator[name].apply mediator, arguments
    return

  io
