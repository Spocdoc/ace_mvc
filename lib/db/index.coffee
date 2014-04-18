Mongo = require './mongo'
mongodb = require 'mongo-fork'
redis = require 'redis'
{queue} = require 'lodash-fork'
clone = require 'diff-fork/clone'
diff = require 'diff-fork'
OJSON = require 'ojson'
Emitter = require 'events-fork/emitter'
debug = global.debug 'ace:server:db'
debugError = global.debug 'error'
async = require 'async'
fixQuery = require './fix_query'
Reject = require '../error/reject'
Conflict = require '../error/conflict'

checkMutation = (origin, cb) ->
  return true unless origin.readOnly
  cb new Reject 'NOMUT'
  false

checkId = (id, cb) ->
  return true if id instanceof mongodb.ObjectID
  cb new Reject "ID"
  false

replaceId = (id, cb) ->
  if typeof id is 'string'
    try
      id = new mongodb.ObjectID id
    catch _error
      cb new Reject "ID"
      return false
  else unless checkId id,cb
    return false
  id

module.exports = class Db extends Mongo
  emit: Emitter.emit

  on: (event, fn, ctx) ->
    @sub.subscribe event unless @_emitter and @_emitter[event]
    Emitter.on.call this, event, fn, ctx

  off: (event, fn, ctx) ->
    if @_emitter
      unless event
        @off event for event in Object.keys @_emitter
      else
        Emitter.off.call this, event, fn, ctx
        @sub.unsubscribe event unless @_emitter[event]
    this

  close: (cb) ->
    super =>
      @sub.on 'end', => cb?()
      @pub.on 'end', => @sub.quit()
      @pub.quit()

  constructor: (options) ->
    dbInfo = options['mongodb']
    redisInfo = options['redis']

    @pub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    @sub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    super dbInfo.db, dbInfo.host, dbInfo.port

    @sub.on 'message', (channel, str) =>
      # use JSON, not OJSON, to avoid re-converting
      args = JSON.parse str
      @emit channel, args

      # remove subscription if a deletion
      if args[1] is 'delete' and @_emitter and @_emitter[channel]
        @sub.unsubscribe channel
        delete @_emitter[channel]

      return

  @channel = (coll, id) ->
    id = id._id if id._id
    id = id.oid if id.oid
    "#{coll}:#{id}"

  create: (origin, coll, doc, cb) ->
    debug "Got create request with",coll,doc
    return unless checkMutation(origin, cb) and checkId(doc._id, cb)
    return cb new Reject "VERSION" unless doc['_v'] >= 1
    @run 'insert', coll, doc, (err) -> cb err

  readIds: (origin, coll, ids, versions, cb, validateQuery) ->
    # build a map from id to version (docs may be out of order)
    # default reply is reject
    versionArray = versions; versions = {}
    reply = {}; reject = [new Reject 'EMPTY']; ok = []
    for version, i in versionArray
      return unless id = ids[i] = replaceId(ids[i], cb)
      versions[id] = version
      reply[id] = reject

    async.waterfall [
      (next) =>
        query = '_id': '$in': ids

        if validateQuery
          validateQuery query, next
        else
          next null, query

      (query, next) =>
        # get only the id and version
        @run 'find', coll, query, {'_id': 1, '_v': 1}, next

      (docs, next) =>
        fetchIds = []

        for doc in docs
          id = doc._id # ObjectId
          if doc._v is versions[id]
            reply[id] = ok
          else
            fetchIds.push id

        if fetchIds.length
          @run 'find', coll, {'_id': '$in': fetchIds}, next
        else
          next null, []

      (docs, next) =>
        for doc in docs
          reply[doc._id] = [null, doc]
        next null, reply

    ], cb

  query: (origin, coll, query, limit, sort, cb, validateQuery) ->
    async.waterfall [
      # modify the query in place if necessary
      (next) =>
        spec =
          query: fixQuery(query)
          sort: sort
          limit: limit

        if validateQuery
          validateQuery spec, (err, spec_) =>
            return next err if err?
            next null, spec_ or spec
        else
          next null, spec

      (spec, next) =>
        {query,sort,limit} = spec

        limit ?= 1

        # mongo treats full text searches totally differently from find commands that don't involve full text.
        # $text is used here to normalize the client API. it's not a valid mongo field
        # search = query.$text
        # delete query.$text
        # if search
        #   @run 'text', coll,
        #     search: search
        #     limit: limit
        #     filter: query
        #     next
        # else
        if limit > 1
          @run 'find', coll, query, limit: limit, sort: sort, next
        else
          @run 'findOne', coll, query, next

    ], (err, docs) =>
      docs = [docs] if docs and !Array.isArray(docs)
      cb err, docs

  read: (origin, coll, id, version, query, limit, sort, cb, validateDoc) ->
    debug "Got read request with",origin.id,coll,id,version,query,limit,sort

    if id
      if Array.isArray id
        @readIds origin, coll, id, version, cb, validateDoc
      else # read single id
        return unless id = replaceId id, cb

        async.waterfall [
          (next) => @run 'findOne', coll, {_id: id}, next

          (doc, next) =>
            return cb new Reject 'EMPTY' unless doc
            return next() unless (doc['_v'] ||= 1) > (version || 0)

            if validateDoc
              validateDoc doc, (err) =>
                return next err if err?
                next null, doc
            else
              next null, doc

        ], cb

    else if query
      @query origin, coll, query, limit, sort, cb, validateDoc

    return

  update: (origin, coll, id, version, ops, cb, validateUpdate) ->
    debug "Got update request with",coll,id,version,ops
    return unless checkMutation(origin, cb) and id = replaceId(id, cb)
    original = doc = moreOps = undefined

    appliedToVersion = version

    async.waterfall [
      (next) => @run 'findOne', coll, {_id: id}, next

      (doc_, next) =>
        return cb new Reject "EMPTY" unless doc = doc_
        return cb new Conflict docVersion unless !version? or version is docVersion = (doc['_v'] ? 1)

        original = clone doc
        doc = diff.patch doc, ops

        if validateUpdate
          validateUpdate original, ops, doc, (err, moreOps) -> next err, moreOps or null # to ensure arg count is right
        else
          next null, null

      (moreOps_, next) =>
        if moreOps = moreOps_
          # complex merge required for toMongo
          doc = diff.patch(doc, moreOps)
          mergedOps = diff(original, doc)
          spec = diff.toMongo mergedOps, doc
        else
          spec = diff.toMongo ops, doc

        # increment version
        (spec['$inc'] ||= {})['_v'] = if moreOps then 2 else 1
        appliedToVersion = doc['_v']

        if version?

          # hack to work around 2.5+ btree text index corruption
          reindexed = false
          doUpdate = =>
            @run 'update', coll, {_id: id, _v: doc['_v']}, spec, (err, updated) =>
              if !reindexed and err? and err.code is 10287 # XXX HARDCODED mongo error requiring a reindex
                debugError "Got Mongo error 10287 so doing reIndex",err
                reindexed = true
                @run 'reIndex', coll, (err) =>
                  return next err if err?
                  doUpdate()
              next err, updated
          doUpdate()

        else
          @run 'findAndModify', coll, {_id: id}, null, spec, {fields: _v: 1}, (err, doc) ->
            return next err if err?
            appliedToVersion = doc['_v']
            next null, 1

      (updated, next) =>
        return cb new Conflict() unless updated

        if moreOps
          cb null, appliedToVersion+1, moreOps # send moreOps in the callback (so the original updater updates their client doc)
          @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'update',coll,id.toString(),appliedToVersion,[]])
          @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'update',coll,id.toString(),appliedToVersion+1,ops])
        else
          cb()
          @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'update',coll,id.toString(),appliedToVersion,ops])

    ], (err) =>
      if err?
        debugError "Database error doing update: ",err
      cb err

    return

  delete: (origin, coll, id, cb, validateDelete) ->
    debug "Got delete request with",coll,id
    return unless checkMutation(origin, cb) and id = replaceId(id, cb)

    async.waterfall [
      (next) =>
        if validateDelete
          @run 'findOne', coll, {_id: id}, (err, doc) =>
            return next err if err?
            validateDelete doc, next
        else
          next()

      (next) =>
        @run 'remove', coll, {_id: id}, next

    ], (err) =>
      return cb err if err?
      cb()
      @pub.publish Db.channel(coll,id), OJSON.stringify([origin.id,'delete',coll,id.toString()])

    return

  distinct: (origin, coll, query, key, cb, validateQuery) ->
    query = fixQuery(query)
    # delete query.$text # not supported as a regular query type in mongoDB

    async.waterfall [
      (next) =>
        if validateQuery
          validateQuery query, (err, query_) =>
            return next err if err?
            next null, query_ or query
        else
          next null, query

      (query, next) =>
        @run 'distinct', coll, key, query, cb

    ], cb


