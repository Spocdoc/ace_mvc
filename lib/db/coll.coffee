Doc = require './doc'
ObjectID = global.mongo.ObjectID

class Coll
  constructor: (@db, @name) ->
    @docs = {}

  create: (spec) ->
    doc = read(null, spec)
    doc.create()
    doc

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

  # TODO these are for memory management
  _unref: (doc) ->
  _ref: (doc) ->

module.exports = Coll

