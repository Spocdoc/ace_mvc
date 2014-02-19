sockio = require 'sockio-fork'
redis = require 'redis'
RedisStore = require 'sockio-fork/redis_store'

module.exports = (server, options) ->
  redisInfo = options['redis']

  io = sockio.listen(server)
  io.set 'store', new RedisStore
    redis: redis
    redisPub: pub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    redisSub: sub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    redisClient: cli = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options

  io.set 'browser client', false

  # flashsocket causes problems during close -- it listens on a separate socket and there's no way to get access to it to shut it down

  io.configure 'development', ->
    io.set 'log level', 3
    io.set 'transports', [
      'websocket'
      # 'flashsocket'
      'htmlfile'
      'xhr-polling'
    ]

  io.configure 'production', ->
    io.set 'log level', 1
    io.set 'transports', [
      'websocket'
      # 'flashsocket'
      'htmlfile'
      'xhr-polling'
    ]

  # assumes that close() has already been called to refuse new connections
  io.exit = (cb) ->
    for client in io.sockets.clients()
      client.disconnect()

    # now close redis connections
    cli.on 'end', -> cb?()
    sub.on 'end', -> cli.quit()
    pub.on 'end', -> sub.quit()
    pub.quit()
    return

  io
