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

checkErr = (err, cb) ->
  if err
    cb.reject err.message
    false
  else
    true

class Db extends Mongo
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

    @sub.on 'message', (channel, message) =>
      # use JSON, not OJSON, to avoid re-converting
      data = JSON.parse message
      [data[2]['c'], data[2]['i']] = channel.split ':'

      @emit channel, data[0], data[1], data[2]

      # remove subscription if a deletion
      if data[0] is 'delete' and @_emitter and @_emitter[channel]
        @sub.unsubscribe channel
        delete @_emitter[channel]

      return

  @channel = (coll, id) -> "#{coll}:#{id}"

  create: (origin, coll, doc, cb) ->
    debug "Got create request with",arguments...

    return unless checkId(doc._id, cb)
    return cb.reject "Version must be 1" unless doc['_v'] is 1

    @run 'insert', coll, doc, (err) ->
      return unless checkErr(err, cb)
      cb.ok()
      return
    return

  read: (origin, coll, id, version, cb, query, sort, limit) ->
    debug "Got read request with",arguments...
    doc = undefined

    if id
      return unless id = replaceId(id, cb)

      async.waterfall [
        (next) => @run 'findOne', coll, {_id: id}, next
        (_doc, next) =>
          doc = _doc
          return cb.noDoc() unless doc
          return cb.ok() unless (doc['_v'] ||= 1) > version
          if cb.validate? then cb.validate(doc, next) else next()
        (next) => cb.doc doc
      ], (err) -> cb.reject err.message if err?

    else if query
      spec =
        query: query
        sort: sort
        limit: limit

      async.waterfall [
        (next) => if cb.validateQuery? then cb.validateQuery(spec, next) else next()
        (next) =>
          if limit? and limit > 1
            @run 'find', coll, query, limit: limit, sort: sort, next
          else
            @run 'findOne', coll, query, next
        (_doc, next) =>
          doc = _doc
          return cb.noDoc() if !doc || Array.isArray(doc) && !doc.length
          if cb.validate? then cb.validate(doc, next) else next()
        (next) => cb.doc doc
      ], (err) -> cb.reject err.message if err?

    else
      cb.reject 'invalid read'

    return

  update: (origin, coll, id, version, ops, cb) ->
    debug "Got update request with",arguments...
    return unless id = replaceId(id, cb)
    moreOps = undefined

    async.waterfall [
      (next) => @run 'findOne', coll, {_id: id}, next

      (doc, next) =>
        return cb.noDoc() unless doc
        return cb.badVer doc['_v'] unless version is (doc['_v'] ? 1)

        # TODO this ridiculousness is entirely because toMongo doesn't work with overlapping sequential updates
        orig = clone doc
        to = diff.patch(to = doc, ops)
        doc = orig

        if cb.validate?
          cb.validate ops, to, (err, moreOps_) -> moreOps = moreOps_; next err, doc,to
        else
          next null, doc,to

      (doc, to, next) =>
        # TODO also because of toMongo restriction
        ops = diff doc, to
        spec = diff.toMongo ops, to

        # increment version
        if doc['_v']?
          (spec['$inc'] ||= {})['_v'] = if moreOps then 2 else 1
        else
          (spec['$set'] ||= {})['_v'] = if moreOps then 3 else 2

        @run 'update', coll, {_id: id, _v: doc['_v']}, spec, next

      (updated, next) =>
        return cb.badVer() unless updated

        if moreOps
          cb.update version+1, moreOps
          @pub.publish Db.channel(coll,id), OJSON.stringify(['update',origin,{'e': version, 'd': []}])
          @pub.publish Db.channel(coll,id), OJSON.stringify(['update',origin,{'e': version+1, 'd': ops}])
        else
          cb.ok()
          @pub.publish Db.channel(coll,id), OJSON.stringify(['update',origin,{'e': version, 'd': ops}])

    ], (err) -> cb.reject err.message if err?

    return

  delete: (origin, coll, id, cb) ->
    debug "Got delete request with",arguments...
    return unless id = replaceId(id, cb)

    @run 'remove', {_id: id}, (err) ->
      return unless checkErr(err, cb)
      cb.ok()
      @pub.publish Db.channel(coll,id), OJSON.stringify(['delete',origin])
      return
    return

module.exports = Db
