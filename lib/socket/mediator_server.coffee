Reject = require '../error/reject'
emptyFunc = ->
trueFunc = -> true

module.exports = class MediatorServer
  constructor: (@db, @sock) ->

  # these should exist and be empty in case the app overrides Mediator and calls them during the server render
  @prototype[name] = emptyFunc for name in [
    'unsubscribe'
    'subscribed'
    'disconnect'
  ]
  @prototype[name] = trueFunc for name in [
    'subscribe'
  ]

  clientCreate: (coll, doc) ->
    if @subscribe coll, doc._id
      @sock.emit 'create', coll, doc
    return

  cookies: (cookies, cb) -> cb()

  run: (coll, id, version, cmd, args, cb) -> cb new Reject "UNHANDLED"

  for method in ['update','delete','distinct','create','read']
    do (method) =>
      @prototype['_' + method] = @prototype[method] = ->
        @db[method].apply @db, [@sock, arguments...]

  # subscribe to updates when creating a document
  @prototype.create = (coll, doc, cb) ->
    @db.create @sock, coll, doc, (err) =>
      return cb err if err?
      @subscribe coll, ''+doc._id
      cb.apply null, arguments

  @prototype._read = (coll, id, version, query, limit, sort, cb, validateDoc) ->
    # allow optional args 
    ARGS = 8
    if (len = arguments.length) < ARGS
      if typeof arguments[len-2] is 'function'
        # then last 2 were passed
        validateDoc = arguments[len-1]
        arguments[len-1] = null
        cb = arguments[len-2]
        arguments[len-2] = null
      else if len < ARGS-1
        cb = arguments[len-1]
        arguments[len-1] = null
    @db.read @sock, coll, id, version, query, limit, sort, cb, validateDoc

  # can send array of ids to re-read or a query. 
  #   - an array of ids leads to map replies from id to array of arguments (full documents, array with error, or empty array)
  #   - query leads to db returning an array of full documents or a single document. 
  # 
  # wrapper unsubscribes from rejects, subscribes new docs and changes the
  # returned array to be an array of full documents or ids (based on whether
  # it's subscribed or not)
  @prototype.read = (coll, id, version, query, limit, sort, cb, validateDoc) ->
    # allow optional args 
    ARGS = 8
    if (len = arguments.length) < ARGS
      if typeof arguments[len-2] is 'function'
        # then last 2 were passed
        validateDoc = arguments[len-1]
        arguments[len-1] = null
        cb = arguments[len-2]
        arguments[len-2] = null
      else if len < ARGS-1
        cb = arguments[len-1]
        arguments[len-1] = null

    if Array.isArray id # reply will be a map
      @db.read @sock, coll, id, version, query, limit, sort, ((err, obj) =>
        for id, arr of obj
          if arr[0]?
            @unsubscribe coll, id
          else
            @subscribe coll, id
        cb.apply null, arguments), validateDoc
    else
      @db.read @sock, coll, id, version, query, limit, sort, ((err, docs) =>
        if err? # error reading this id. unsubscribe.
          @unsubscribe coll, id if id
          return cb err

        if docs
          if Array.isArray docs # then sent a query... have an array of full docs
            for doc, i in docs
              @clientCreate coll, doc
              docs[i] = ''+doc._id

          else # single document
            @subscribe coll, ''+docs._id

        cb.apply null, arguments), validateDoc
    return

