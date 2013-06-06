# ASIDE: serious coffee script fail with all these useless return statements

Mongo = require './mongo'
mongodb = require 'mongodb'
redis = require 'redis'
queue = require '../../queue'
dtom = require '../../diff/to_mongo'
clone = require '../../clone'
diff = require '../../diff'
OJSON = require '../../ojson'
Emitter = require '../../events/emitter'
{include} = require '../../mixin'
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

class Db
  include Db, Emitter

  constructor: (dbInfo, redisInfo) ->
    @pub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    @sub = redis.createClient redisInfo.host, redisInfo.port, redisInfo.options
    @mongo = new Mongo dbInfo.host, dbInfo.db

    @subscriptions = {}

    @sub.on 'message', (channel, message) =>
      # use JSON, not OJSON, to avoid re-converting
      data = JSON.parse message
      [data[2]['c'], data[2]['i']] = channel.split ':'
      @emit channel, data[0], data[1], data[2]
      return

  @channel = (coll, id) -> "#{coll}:#{id}"

  create: (origin, coll, doc, cb) ->
    debug "Got create request with",arguments...

    return unless checkId(doc._id, cb)
    return cb.reject "Version must be 1" unless doc['_v'] is 1

    @mongo.run 'insert', coll, doc, (err) ->
      return unless checkErr(err, cb)
      cb.ok()
      return
    return

  read: (origin, coll, id, version, cb) ->
    debug "Got read request with",arguments...
    return unless id = replaceId(id, cb)

    async.waterfall [
      (next) => @mongo.run 'findOne', coll, {_id: id}, next
      (doc, next) =>
        return cb.noDoc() unless doc
        doc['_v'] ||= 1
        return cb.ok() unless doc['_v'] > version

        if cb.validate?
          cb.validate doc, (err) -> next err, doc
        else
          next null, doc

      (doc, next) =>
        cb.doc doc

    ], (err) -> cb.reject err.message if err?
    return

  update: (origin, coll, id, version, ops, cb) ->
    debug "Got update request with",arguments...
    return unless id = replaceId(id, cb)
    moreOps = undefined

    async.waterfall [
      (next) => @mongo.run 'findOne', coll, {_id: id}, next

      (doc, next) =>
        return cb.noDoc() unless doc
        return cb.badVer doc['_v'] unless version is (doc['_v'] ? 1)

        # TODO this ridiculousness is entirely because dtom doesn't work with overlapping sequential updates
        orig = clone doc
        to = diff.patch(to = doc, ops)
        doc = orig

        if cb.validate?
          cb.validate ops, to, (err, moreOps_) -> moreOps = moreOps_; next err, doc,to
        else
          next null, doc,to

      (doc, to, next) =>
        # TODO also because of dtom restriction
        ops = diff doc, to
        spec = dtom ops, to

        # increment version
        if doc['_v']?
          (spec['$inc'] ||= {})['_v'] = if moreOps then 2 else 1
        else
          (spec['$set'] ||= {})['_v'] = if moreOps then 3 else 2

        @mongo.run 'update', coll, {_id: id, _v: doc['_v']}, spec, next

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

    @mongo.run 'remove', {_id: id}, (err) ->
      return unless checkErr(err, cb)
      cb.ok()
      @pub.publish Db.channel(coll,id), OJSON.stringify(['delete',origin])
      return
    return

  subscribe: (origin, coll, id, version, cb) ->
    debug "Got subscribe request with",arguments...
    return unless id = replaceId(id, cb)

    c = Db.channel(coll, id)
    unless @subscriptions[c]
      @sub.subscribe c
      @subscriptions[c] = true

    @mongo.run 'findOne', coll, {_id: id}, (err, doc) =>
      return unless checkErr(err, cb)
      unless doc
        @sub.unsubscribe c
        delete @subscriptions[c]
        cb.noDoc()
        return
      return cb.doc doc if (doc['_v'] ||= 1) != version
      cb.ok()
      return
    return


  unsubscribe: (origin, coll, id, cb) ->
    debug "Got unsubscribe request with",arguments...
    return unless id = replaceId(id, cb)

    c = Db.channel(coll, id)

    unless @subscriptions[c]
      @sub.unsubscribe c
      delete @subscriptions[c]

    cb.ok()
    return


module.exports = Db
