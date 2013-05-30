OJSON = require '../../ojson'
sockio = require("socket.io")
redis = require 'redis'
RedisStore = require 'socket.io/lib/stores/redis'
{extend} = require '../../mixin'
Listener = require '../../events/listener'
Db = require './db'

# called with this = sock
onevent = (event, origin, ojSpec) ->
  return if origin == @id
  @emit event, ojSpec

module.exports = (db, redisInfo, server) ->

  io = sockio.listen(server)
  io.set 'store', new RedisStore
    redis: redis
    redisPub: redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    redisSub: redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    redisClient: redis.createClient redisInfo.host, redisInfo.port, redisInfo.options

  io.set 'browser client', false

  io.configure 'development', ->
    io.set 'log level', 2
    io.set 'transports', [
      'websocket'
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
    extend sock, Listener # no name clashes

    sock.on 'disconnect', ->
      sock.listenOff db
      return

    sock.on 'create', (data, cb) ->
      db.create sock.id, data['c'], OJSON.fromOJSON(data['v']), cb

    sock.on 'read', (data, cb) ->
      db.read sock.id, data['c'], data['i'], data['e'], cb

    sock.on 'update', (data, cb) ->
      db.update sock.id, data['c'], data['i'], data['e'], OJSON.fromOJSON(data['d']), cb

    sock.on 'delete', (data, cb) ->
      db.delete sock.id, data['c'], data['i'], cb

    sock.on 'subscribe', (data, cb) ->
      c = data['c']
      i = data['i']

      sock.listenOn db, Db.channel(c,i), onevent
      db.subscribe sock.id, c, i, data['e'], cb

    sock.on 'unsubscribe', (data, cb) ->
      c = data['c']
      i = data['i']

      sock.listenOff db, Db.channel(c,i)
      db.unsubscribe sock.id, c, i, cb

  io
