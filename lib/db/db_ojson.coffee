Coll = require './coll'
Doc = require './doc'
OJSON = require '../ojson'
{extend, include} = require '../mixin'

module.exports = (Db) ->
  OJSON.register 'Db': Db

  Db.prototype['_ojson'] = true
  Doc.prototype['_ojson'] = true

  Db.prototype.toJSON = ->
    colls = {}
    for name, coll of @colls
      c = colls[name] = {}
      for id, doc of coll.docs
        c[id] = OJSON.toOJSON doc.doc
    colls

  Db.fromJSON = (obj) ->
    db = new Db

    for name, c of obj
      coll = db.colls[name] = new Coll db, name
      for id, doc of c
        coll.docs[id] = new Doc coll, id, doc

    db

