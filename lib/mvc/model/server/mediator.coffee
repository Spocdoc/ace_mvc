Callback = require './callback'
Db = require './db'
OJSON = require '../../../utils/ojson'
Listener = require '../../../utils/events/listener'
{include} = require '../../../utils/mixin'

class Mediator
  include @, Listener

  constructor: (@db, @sock) ->
    @origin = @sock.id

  disconnect: -> @listenOff @db

  doSubscribe: (coll, id) ->
    unless already = @isListening @db, channel=Db.channel(coll,id)
      @listenOn @db, channel, @onevent
    !already

  doUnsubscribe: (coll, id) ->
    @listenOff @db, Db.channel(coll,id)

  onevent: (event, origin, ojSpec) ->
    return if origin == @origin
    @sock.emit event, ojSpec

  isSubscribed: (coll, id) -> @isListening Db.channel coll, id

  clientCreate: (coll, doc) ->
    @sock.emit 'create',
      'c': coll
      'v': OJSON.toOJSON doc

  create: (coll, doc, cb) ->
    @db.create @origin, coll, doc, cb

  read: (coll, id, version, cb, query, sort, limit) ->
    cb.doc = (docs) ->
      if Array.isArray docs
        reply = []; i = 0
        for doc,i in docs
          reply[i] = id = doc._id
          @clientCreate coll, doc if @doSubscribe coll, id
        docs = reply

      Callback.prototype.doc.call cb, docs

    cb.ok = ->
      @doSubscribe coll, id
      Callback.prototype.ok.call cb

    @db.read @origin, coll, id, version, cb, query, sort, limit

  update: (coll, id, version, ops, cb) ->
    @db.update @origin, coll, id, version, ops, cb

  delete: (coll, id, cb) ->
    @db.delete @origin, coll, id, cb

  run: (coll, id, version, cmd, args, cb) ->
    cb.reject "unhandled"

module.exports = Mediator
