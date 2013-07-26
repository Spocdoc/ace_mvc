Db = require './db'
Listener = require '../../../utils/events/listener'
{include} = require '../../../utils/mixin'
MediatorServer = require './mediator_server'

module.exports = class MediatorClient extends MediatorServer
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

  disconnect: -> @listenOff @db

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
