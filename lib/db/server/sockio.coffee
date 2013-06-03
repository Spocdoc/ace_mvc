OJSON = require '../../ojson'
sockio = require("socket.io")
redis = require 'redis'
RedisStore = require 'socket.io/lib/stores/redis'
{extend} = require '../../mixin'
Db = require './db'
Callback = require './callback'

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
    sock.mediator = new Mediator db, sock

    sock.on 'disconnect', ->
      sock.mediator.disconnect()

    sock.on 'create', (data, cb) ->
      sock.mediator.create data['c'], OJSON.fromOJSON(data['v']), new Callback cb

    sock.on 'read', (data, cb) ->
      sock.mediator.read data['c'], data['i'], data['e'], new Callback cb

    sock.on 'update', (data, cb) ->
      sock.mediator.update data['c'], data['i'], data['e'], OJSON.fromOJSON(data['d']), new Callback cb

    sock.on 'delete', (data, cb) ->
      sock.mediator.delete data['c'], data['i'], new Callback cb

    sock.on 'subscribe', (data, cb) ->
      sock.mediator.subscribe data['c'], data['i'], data['e'], new Callback cb

    sock.on 'unsubscribe', (data, cb) ->
      sock.mediator.unsubscribe data['c'], data['i'], new Callback cb

  io
