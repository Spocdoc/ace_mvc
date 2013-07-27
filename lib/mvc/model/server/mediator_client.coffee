Db = require './db'
Listener = require '../../../utils/events/listener'
{extend} = require '../../../utils/mixin'
MediatorServer = require './mediator_server'

module.exports = class MediatorClient extends MediatorServer
  constructor: (@db, @sock) ->
    @origin = @sock.id
    extend sock, Listener unless sock.listenOn

  doSubscribe: (coll, id) ->
    unless already = @sock.isListening @db, channel=Db.channel(coll,id)
      @sock.listenOn @db, channel, (args) =>
        return if args[0] == @origin
        @sock.emit.apply @sock, args[1..]
    !already

  doUnsubscribe: (coll, id) ->
    @sock.listenOff @db, Db.channel(coll,id)

  isSubscribed: (coll, id) -> @sock.isListening Db.channel coll, id

  disconnect: -> @sock.listenOff @db

  read: (coll, id, version, query, limit, sort, cb) ->
    proxy = Object.create cb

    proxy.doc = (docs) =>
      if Array.isArray docs
        @clientCreate coll, doc for doc,i in docs when @doSubscribe coll, doc._id
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

    @dbRead coll, id, version, query, limit, sort, proxy
