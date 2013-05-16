OJSON = require '../../ojson'
sockio = require("socket.io")
{extend} = require '../../mixin'
Listener = require '../../events/listener'

# called with this = sock
onevent = (event, origin, ojSpec) ->
  return if origin == @id
  @emit event, ojSpec

module.exports = (db, server) ->

  io = sockio.listen(server)

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

      sock.listenOn db, db.channel(c,i), onevent
      db.subscribe sock.id, c, i, data['e'], cb

    sock.on 'unsubscribe', (data, cb) ->
      c = data['c']
      i = data['i']

      sock.listenOff db, db.channel(c,i)
      db.unsubscribe sock.id, c, i, cb

