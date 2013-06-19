Doc = require './doc'
ObjectID = global.mongo.ObjectID
Query = require './query'
OJSON = require '../ojson'

class Coll
  constructor: (@db, @name) ->
    @docs = {}

  # id is optional
  create: (spec, id) ->
    doc = @read(id, spec)
    doc.create()
    doc

  # spec is optional
  read: (id = new ObjectID, spec) ->
    if typeof id is 'string'
      try
        id = new ObjectID(id) # on the server, mongodb's ObjectID throws an exception if it's an invalid id
      catch _error
    return d if d = @docs[id]
    d = new Doc this, id, spec
    @docs[id] = d

  update: (id, ops) ->
    read(id).update(ops)

  delete: (id) ->
    d = @docs[id]
    d._delete()
    delete @docs[id]
    return

  findOne: (spec, cb) ->
    query = new Query spec
    for id, doc of @docs
      return cb null, doc if query.exec doc.doc

    @db.findOne this, spec, (err) =>
      return cb 'nodoc' unless err
      return cb err unless err[0] is 'doc'

      doc = OJSON.fromOJSON err[1]
      cb null, @read doc._id, doc
      return
    return

  # TODO these are for memory management
  _unref: (doc) ->
  _ref: (doc) ->

module.exports = Coll

