Coll = require './coll'
io = global.io
OJSON = require '../ojson'
debug = global.debug 'ace:db'

class Db
  constructor: (path='/') ->
    @colls = {}

    @sock = io.connect path

    @sock.on 'create', (data) =>
      coll = data['c']
      doc = OJSON.fromOJSON data['v']
      @coll(coll).read(doc._id).serverCreate(doc)
      return

    @sock.on 'update', (data) =>
      coll = data['c']
      id = data['i']
      version = data['e']
      ops = data['d']
      @coll(coll).read(id).serverUpdate(version, ops)
      return

    @sock.on 'delete', (data) =>
      coll = data['c']
      id = data['i']
      @coll(coll).read(id).serverDelete()

  coll: (coll) ->
    @colls[coll] ||= new Coll this, coll

  subscribe: (doc, cb) ->
    debug "DB emitting subscribe request over sock #{@sock} for #{doc.coll.name}/#{doc.id}/#{doc.doc._v}"
    @sock.emit 'subscribe',
      'c': doc.coll.name
      'i': doc.id
      'e': doc.doc._v
      cb

  unsubscribe: (doc, cb) ->
    debug "DB emitting unsubscribe request over sock #{@sock} for #{doc.coll.name}/#{doc.id}"
    @sock.emit 'unsubscribe',
      'c': doc.coll.name
      'i': doc.id
      cb

  create: (doc, cb) ->
    debug "DB emitting create request over sock #{@sock} for #{doc.coll.name}/#{doc.id}", OJSON.toOJSON doc.doc
    @sock.emit 'create', {'c': doc.coll.name, 'v': OJSON.toOJSON doc.doc}, cb

  read: (doc, cb) ->
    debug "DB emitting read request over sock #{@sock} for #{doc.coll.name}/#{doc.id}/#{doc.doc._v}"
    @sock.emit 'read', {'c': doc.coll.name, 'i': doc.id, 'e': doc.doc._v}, cb

  update: (doc, ops, cb) ->
    debug "DB emitting update request over sock #{@sock} for #{doc.coll.name}/#{doc.id}/#{doc.doc._v}", OJSON.toOJSON ops
    @sock.emit 'update', {'c': doc.coll.name, 'i': doc.id, 'e': doc.doc._v, 'd': OJSON.toOJSON ops}, cb

  delete: (doc, cb) ->
    debug "DB emitting delete request over sock #{@sock} for #{doc.coll.name}/#{doc.id}/#{doc.doc._v}"
    @sock.emit 'delete', {'c': doc.coll.name, 'i': doc.id}, cb

module.exports = Db
