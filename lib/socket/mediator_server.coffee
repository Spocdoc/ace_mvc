OJSON = require 'ojson'

emptyFunc = ->
trueFunc = -> true

module.exports = class MediatorServer
  constructor: (@db, @sock) ->

  # these should exist and be empty in case the app overrides Mediator and calls them during the server render
  @prototype[name] = emptyFunc for name in [
    'doUnsubscribe'
    'isSubscribed'
    'disconnect'
  ]
  @prototype[name] = trueFunc for name in [
    'doSubscribe'
  ]

  clientCreate: (coll, doc) ->
    if @doSubscribe coll, doc._id
      @sock.emit 'create', coll, OJSON.toOJSON(doc)
    return

  cookies: (cookies, cb) -> cb()

  run: (coll, id, version, cmd, args, cb) -> cb.reject "unhandled"

  for method in ['create','read','update','delete','distinct']
    do (method) =>
      capitalized = method.charAt(0).toUpperCase() + method.substr(1)

      @prototype['db' + capitalized] = @prototype['base' + capitalized] = @prototype[method] = ->
        @db[method].apply @db, [@sock, arguments...]

  @prototype.create = @prototype.baseCreate = (coll, doc, cb) ->
    proxy = Object.create cb
    id = doc._id

    proxy.ok = =>
      @doSubscribe coll, id
      cb.ok.apply cb, arguments

    proxy.update = (version, ops) =>
      @doSubscribe coll, id
      cb.update version, ops

    @dbCreate coll, doc, proxy

  @prototype.read = @prototype.baseRead = (coll, id, version, query, limit, sort, cb) ->
    proxy = Object.create cb

    proxy.doc = (docs) =>
      if Array.isArray docs
        @clientCreate coll, doc for doc in docs
      else
        @doSubscribe coll, id

      cb.doc docs

    proxy.ok = =>
      @doSubscribe coll, id
      cb.ok()

    proxy.reject = (msg) =>
      if Array.isArray id
        ids = id
        @doUnsubscribe coll, id for id in ids
      else
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
