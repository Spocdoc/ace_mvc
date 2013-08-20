# ASIDE: serious coffee script fail with all these useless return statements

Mongo = require './mongo'
mongodb = require 'mongodb'
redis = require 'redis'
queue = require '../../../utils/queue'
clone = require '../../../utils/clone'
diff = require '../../../utils/diff'
OJSON = require '../../../utils/ojson'
Emitter = require '../../../utils/events/emitter'
debug = global.debug 'ace:server:db'
async = require 'async'
callback = require './callback'
fixQuery = require './fix_query'

checkId = (id, cb) ->
  unless id instanceof mongodb.ObjectID
    cb(['rej', "Invalid id"])
    false
  else
    true

replaceId = (id, cb) ->
  if typeof id is 'string'
    try
      id = new mongodb.ObjectID id
    catch _error
      cb.reject 'Invalid id'
      return false
  else unless checkId id,cb
    return false
  id

checkMutation = (origin, cb) ->
  if origin.readOnly
    cb.reject "Mutating events disallowed"
    false
  else
    true

checkErr = (err, cb) ->
  if err
    cb.reject err.message
    false
  else
    true

module.exports = class Db extends Mongo
  emit: Emitter.emit

  on: (event, fn, ctx) ->
    @sub.subscribe event unless @_emitter and @_emitter[event]
    Emitter.on.call this, event, fn, ctx

  off: (event, fn, ctx) ->
    Emitter.off.call this, event, fn, ctx
    @sub.unsubscribe event unless @_emitter and @_emitter[event]
    this

  constructor: (dbInfo, redisInfo) ->
    @pub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    @sub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    super dbInfo.host, dbInfo.db

    @sub.on 'message', (channel, str) =>
      # use JSON, not OJSON, to avoid re-converting
      args = JSON.parse str
      @emit channel, args

      # remove subscription if a deletion
      if args[1] is 'delete' and @_emitter and @_emitter[channel]
        @sub.unsubscribe channel
        delete @_emitter[channel]

      return

  @channel = (coll, id) -> "#{coll}:#{id}"

  create: (origin, coll, doc, cb) ->
    debug "Got create request with",coll,doc
    return unless checkMutation(origin, cb) and checkId(doc._id, cb)
    return cb.reject "Version must be at least 1" unless doc['_v'] >= 1

    @run 'insert', coll, doc, (err) ->
      return unless checkErr(err, cb)
      cb.ok()
      return
    return

  read: (origin, coll, id, version, query, limit, sort, cb) ->
    debug "Got read request with",coll,id,version,query,limit,sort
    doc = undefined

    if id
      if Array.isArray id
        reply = {}
        versions = {}
        query = '_id': '$in': id
        ok = callback.Read.ok()
        reject = callback.Read.reject()
        for docId, i in id
          return unless id[i] = replaceId docId, cb
          reply[docId] = reject
          versions[docId] = version[i]

        fullDocs = []

        async.waterfall [
          (next) => if cb.validateQuery? then cb.validateQuery(query,next) else next()
          (next) => @run 'find', coll, query, {'_id': 1, '_v': 1}, next
          (docs, next) =>
            for doc in docs
              if doc._v is versions[doc._id]
                reply[doc._id] = ok
              else
                fullDocs.push doc._id

            if fullDocs.length
              @run 'find', coll, {'_id': '$in': fullDocs}, next
            else
              next null, []
          (docs, next) =>
            reply[doc._id] = callback.Read.doc doc for doc in docs
            cb.bulk reply
        ], (err) -> cb.reject err.message if err?

      else
        return unless id = replaceId(id, cb)

        async.waterfall [
          (next) => @run 'findOne', coll, {_id: id}, next
          (_doc, next) =>
            doc = _doc
            return cb.reject() unless doc
            return cb.ok() unless (doc['_v'] ||= 1) > version
            if cb.validate? then cb.validate(doc, next) else next()
          (next) => cb.doc doc
        ], (err) -> cb.reject err.message if err?

    else if query
      spec =
        query: fixQuery(query)
        sort: sort
        limit: limit

      async.waterfall [
        (next) => if cb.validateQuery? then cb.validateQuery(spec, next) else next()
        (next) =>
          {query,sort,limit} = spec

          # mongo treats full text searches totally differently from find commands that don't involve full text.
          # $text is used here to normalize the client API. it's not a valid mongo field
          if query.hasOwnProperty '$text'
            search = query.$text
            delete query.$text
            @run 'text', coll,
              search: search
              limit: limit
              filter: query
              next
          else if limit? and limit > 1
            @run 'find', coll, query, limit: limit, sort: sort, next
          else
            @run 'findOne', coll, query, next
        (doc, next) =>
          if doc?
            doc = [doc] unless Array.isArray doc
          else
            doc = []
          cb.doc doc
          return
      ], (err) -> cb.reject err.message if err?

    else
      cb.reject 'invalid read'

    return

  update: (origin, coll, id, version, ops, cb) ->
    debug "Got update request with",coll,id,version,ops
    return unless checkMutation(origin, cb) and id = replaceId(id, cb)
    moreOps = undefined

    async.waterfall [
      (next) => @run 'findOne', coll, {_id: id}, next

      (doc, next) =>
        return cb.reject() unless doc
        return cb.conflict doc['_v'] unless version is (doc['_v'] ? 1)

        orig = clone doc
        to = diff.patch(doc, ops)
        doc = orig

        if cb.validate?
          cb.validate doc, ops, to, (err, moreOps_) -> moreOps = moreOps_; next err, doc, to
        else
          next null, doc,to

      (doc, to, next) =>
        ops = diff doc, to
        spec = diff.toMongo ops, to

        # increment version
        if doc['_v']?
          (spec['$inc'] ||= {})['_v'] = if moreOps then 2 else 1
        else
          (spec['$set'] ||= {})['_v'] = if moreOps then 3 else 2

        @run 'update', coll, {_id: id, _v: doc['_v']}, spec, next

      (updated, next) =>
        return cb.conflict() unless updated

        if moreOps
          cb.update version+1, moreOps
          @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'update',coll,id.toString(),version,[]])
          @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'update',coll,id.toString(),version+1,ops])
        else
          cb.ok()
          @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'update',coll,id.toString(),version,ops])

    ], (err) -> cb.reject err.message if err?

    return

  delete: (origin, coll, id, cb) ->
    debug "Got delete request with",coll,id
    return unless checkMutation(origin, cb) and id = replaceId(id, cb)

    @run 'remove', coll, {_id: id}, (err) =>
      return unless checkErr(err, cb)
      cb.ok()
      @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'delete',coll,id.toString()])
      return
    return

  distinct: (origin, coll, query, key, cb) ->
    delete query.$text # not supported as a regular query type in mongoDB
    @run 'distinct', coll, key, query, (err, docs) ->
      return unless checkErr(err, cb)
      cb.doc docs
