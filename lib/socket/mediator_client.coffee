Db = require '../db'
Listener = require 'events-fork/listener'
{extend} = require 'lodash-fork'
MediatorServer = require './mediator_server'
debug = global.debug 'ace:mediator'

module.exports = class MediatorClient extends MediatorServer
  constructor: ->
    super
    extend @sock, Listener unless @sock.listenOn

  subscribe: (coll, id) ->
    unless already = @sock.isListening @db, channel=Db.channel(coll,id)
      debug "sock #{@sock.id} listen on #{channel}"
      @sock.listenOn @db, channel, (args) =>
        return if args[0] is @sock.id
        @sock.emit.apply @sock, args[1..]
    !already

  unsubscribe: (coll, id) -> @sock.listenOff @db, Db.channel(coll,id)
  subscribed: (coll, id) -> @sock.isListening Db.channel coll, id

  disconnect: -> @sock.listenOff @db

