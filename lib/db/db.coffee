Coll = require './coll'
io = global.io
OJSON = require '../ojson'

class Db
  constructor: (path='/') ->
    @colls = {}

    @sock = io.connect path

    @sock.on 'create', (data) =>
      coll = data['c']
      doc = OJSON.fromOJSON data['v']
      @get(coll).read(doc._id).serverCreate(doc)
      return

    @sock.on 'update', (data) =>
      coll = data['c']
      id = data['i']
      version = data['e']
      ops = data['d']
      @get(coll).read(id).serverUpdate(version, ops)
      return

    @sock.on 'delete', (data) =>
      coll = data['c']
      id = data['i']
      @get(coll).read(id).serverDelete()

  get: (coll) ->
    @colls[coll] ||= new Coll this, coll

  subscribe: (doc) ->
    @sock.emit 'subscribe',
      'c': doc.coll.name
      'i': doc.id
      'e': doc.doc._v

  unsubscribe: (doc) ->
    @sock.emit 'unsubscribe',
      'c': doc.coll.name
      'i': doc.id

  create: (doc, cb) ->
    @sock.emit 'create', {'c': doc.coll.name, 'v': OJSON.toOJSON doc.doc}, cb

  read: (doc, cb) ->
    @sock.emit 'read', {'c': doc.coll.name, 'i': doc.id, 'e': doc.doc._v}, cb

  update: (doc, ops, cb) ->
    @sock.emit 'update', {'c': doc.coll.name, 'i': doc.id, 'e': doc.doc._v, 'd': OJSON.toOJSON ops}, cb

  delete: (doc, cb) ->
    @sock.emit 'delete', {'c': doc.coll.name, 'i': doc.id}, cb

module.exports = Db
