Db = require './db'
OJSON = require '../../ojson'
Listener = require '../../events/listener'
{include, extend} = require '../../mixin'

class Mediator
  include @, Listener

  constructor: (@db, @sock) ->
    @origin = @sock.id

  disconnect: ->
    @listenOff @db

  doSubscribe: (coll, id) ->
    @listenOn @db, Db.channel(coll,id), @onevent

  doUnsubscribe: (coll, id) ->
    @listenOff @db, Db.channel(coll,id)

  onevent: (event, origin, ojSpec) ->
    return if origin == @origin
    @sock.emit event, ojSpec

  clientCreate: (coll, doc) ->
    @sock.emit 'create',
      'c': coll
      'v': OJSON.toOJSON doc

  create: (coll, doc, cb) ->
    @db.create @origin, coll, doc, cb

  read: (coll, id, version, cb) ->
    @db.read @origin, coll, id, version, cb

  update: (coll, id, version, ops, cb) ->
    @db.update @origin, coll, id, version, ops, cb

  delete: (coll, id, cb) ->
    @db.delete @origin, coll, id, cb

  subscribe: (coll, id, version, cb) ->
    @doSubscribe coll, id
    @db.subscribe @origin, coll, id, version, cb

  unsubscribe: (coll, id, cb) ->
    @doUnsubscribe coll, id
    @db.unsubscribe @origin, coll, id, cb

module.exports = Mediator
