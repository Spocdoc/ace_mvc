Doc = require './doc'
ObjectID = global.mongo.ObjectID

class Coll
  constructor: (@db, @name) ->
    @docs = {}

  create: (spec) ->
    doc = read(null, spec)
    doc.create()
    doc

  read: (id = new ObjectId, spec) ->
    return d if d = @docs[id]
    d = new Doc this, id, spec
    @docs[id] = d

  update: (id, ops) ->
    read(id).update(ops)

  delete: (id) ->
    delete d = @docs[id]
    d._delete()
    return

  # TODO these are for memory management
  _unref: (doc) ->
  _ref: (doc) ->

module.exports = Coll

