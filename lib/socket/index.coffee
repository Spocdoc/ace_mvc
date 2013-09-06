sockio = require 'sockio-fork'
redis = require 'redis'
RedisStore = require 'sockio-fork/redis_store'

module.exports = (server, options) ->
  redisInfo = options['redis']

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

  io
