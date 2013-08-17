OJSON = require '../../../utils/ojson'

emptyFunc = ->

module.exports = class MediatorServer
  constructor: (@db, @sock) ->

  # these should exist and be empty in case the app overrides Mediator and calls them during the server render
  @prototype[empty] = emptyFunc for empty in [
    'doSubscribe'
    'doUnsubscribe'
    'isSubscribed'
    'disconnect'
  ]

  clientCreate: (coll, doc) ->
    @doSubscribe coll, doc._id
    @sock.emit 'create', coll, OJSON.toOJSON(doc)

  cookies: (cookies, cb) -> cb()

  run: (coll, id, version, cmd, args, cb) -> cb.reject "unhandled"

  for method in ['create','read','update','delete','distinct']
    do (method) =>
      @prototype['db' + method[0].toUpperCase() + method[1..]] = @prototype[method] = -> @db[method].apply @db, [@sock, arguments...]

  read: (coll, id, version, query, limit, sort, cb) ->
    proxy = Object.create cb

    proxy.doc = (docs) =>
      @clientCreate coll, doc for doc in docs if Array.isArray docs
      cb.doc docs

    @dbRead coll, id, version, query, limit, sort, proxy
