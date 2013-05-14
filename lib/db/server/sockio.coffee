OJSON = require '../../ojson'
sockio = require("socket.io")

# called with this = sock
onevent = (event, origin, ojSpec) ->
  return if origin == @id
  @emit event, ojSpec

module.exports = (db, server) ->

  io = sockio.listen(server)

  io.on 'connection', (sock) ->

    sock.on 'disconnect', ->
      db.off(0,0,sock)
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

      db.on db.channel(c,i), onevent, sock
      db.subscribe sock.id, c, i, data['e'], cb

    sock.on 'unsubscribe', (data, cb) ->
      c = data['c']
      i = data['i']

      db.off db.channel(c,i), onevent, sock
      db.unsubscribe sock.id, c, i, cb

