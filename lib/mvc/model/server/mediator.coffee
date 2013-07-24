Db = require './db'
OJSON = require '../../../utils/ojson'
Listener = require '../../../utils/events/listener'
{include} = require '../../../utils/mixin'

class Mediator
  include @, Listener

  constructor: (@db, @sock) ->
    @origin = @sock.id

  doSubscribe: (coll, id) ->
    unless already = @isListening @db, channel=Db.channel(coll,id)
      @listenOn @db, channel, @onevent
    !already

  doUnsubscribe: (coll, id) ->
    @listenOff @db, Db.channel(coll,id)

  onevent: (args) ->
    return if args[0] == @origin
    @sock.emit.apply @sock, args[1..]

  isSubscribed: (coll, id) -> @isListening Db.channel coll, id

  clientCreate: (coll, doc) ->
    @doSubscribe coll, doc._id
    @sock.emit 'create', coll, OJSON.toOJSON(doc)

  disconnect: -> @listenOff @db

  cookies: (cookies) ->

  create: (coll, doc, cb) ->
    @db.create @origin, coll, doc, cb

  read: (coll, id, version, query, limit, sort, cb) ->
    proxy = Object.create cb

    proxy.doc = (docs) =>
      if Array.isArray docs
        reply = []; i = 0
        for doc,i in docs
          reply[i] = id = doc._id
          @clientCreate coll, doc if @doSubscribe coll, id
        docs = reply
      else
        @doSubscribe coll, id

      cb.doc docs

    proxy.ok = =>
      @doSubscribe coll, id
      cb.ok()

    proxy.reject = (msg) =>
      @doUnsubscribe coll, id
      cb.reject msg

    proxy.bulk = (reply) =>
      for id,r of reply
        if r[0] is 'r'
          @doUnsubscribe coll, id
        else
          @doSubscribe coll, id
      cb.bulk reply

    @db.read @origin, coll, id, version, query, limit, sort, cb

  update: (coll, id, version, ops, cb) ->
    @db.update @origin, coll, id, version, ops, cb

  delete: (coll, id, cb) ->
    @db.delete @origin, coll, id, cb

  run: (coll, id, version, cmd, args, cb) ->
    cb.reject "unhandled"

  distinct: (coll, query, key, cb) ->
    @db.distinct @origin, coll, query, key, cb

module.exports = Mediator
