# ASIDE: serious coffee script fail with all these useless return statements

Mongo = require './mongo'
mongodb = require 'mongodb'
redis = require 'redis'
queue = require '../../queue'
dtom = require '../../diff/to_mongo'
diff = require '../../diff'
OJSON = require '../../ojson'
Emitter = require '../../events/emitter'
{include} = require '../../mixin'

checkId = (id, cb) ->
  unless id instanceof mongodb.ObjectID
    cb(['rej', "Must provide id"])
    false
  else
    true

checkErr = (err, cb) ->
  if err
    cb(['rej',err.message])
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

  channel: (coll, id) -> "#{coll}:#{id}"

  create: (origin, coll, doc, cb) ->
    return unless checkId(doc._id, cb)
    return cb(['rej', "Version must be 1"]) unless doc._v is 1

    @mongo.run 'insert', coll, doc, (err) ->
      return unless checkErr(err, cb)
      cb()
      return
    return

  read: (origin, coll, id, version, cb) ->
    return unless checkId(id, cb)

    @mongo.run 'findOne', coll, {_id: id}, (err, doc) ->
      return unless checkErr(err, cb)
      return cb(['no']) unless doc
      return cb() unless doc._v > version
      cb(['doc', doc])
      return
    return

  update: (origin, coll, id, version, ops, cb) ->
    return unless checkId(id, cb)

    @mongo.run 'findOne', coll, {_id: id}, (err, doc) =>
      return unless checkErr(err, cb)
      return cb(['no']) unless doc
      return cb(['ver',"v.#{doc._v} is current"]) unless version is doc._v

      to = diff.patch(doc, ops)
      spec = dtom ops, to

      # increment version
      (spec['$inc'] ||= {})['_v'] = 1

      @mongo.run 'update', {_id: id, _v: version}, spec, (err, updated) =>
        return unless checkErr(err, cb)
        return cb(['ver']) unless updated
        cb()
        @pub.publish channel(coll,id), OJSON.stringify(['update',origin,{'e': version, 'd': ops}])
        return
      return
    return

  delete: (origin, coll, id, cb) ->
    return unless checkId(id, cb)

    @mongo.run 'remove', {_id: id}, (err) ->
      return unless checkErr(err, cb)
      cb()
      @pub.publish channel(coll,id), OJSON.stringify(['delete',origin])
      return
    return

  subscribe: (origin, coll, id, version, cb) ->
    c = channel(coll, id)
    unless @subscriptions[c]
      @sub.subscribe c
      @subscriptions[c] = true

    @mongo.run 'findOne', coll, {_id: id}, (err, doc) =>
      return unless checkErr(err, cb)
      unless doc
        @sub.unsubscribe c
        delete @subscriptions[c]
        cb(['no'])
        return
      return cb(['doc', doc]) if doc._v != version
      cb()
      return
    return


  unsubscribe: (origin, coll, id, cb) ->
    c = channel(coll, id)

    unless @subscriptions[c]
      @sub.unsubscribe c
      delete @subscriptions[c]

    cb()
    return


module.exports = Db
