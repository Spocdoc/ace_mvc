OJSON = require '../../../utils/ojson'

methods =
  ok: -> Array.prototype.concat.apply(['o'], arguments)
  doc: (doc) -> ['d', OJSON.toOJSON doc]
  update: (version, ops) -> ['u', version, OJSON.toOJSON ops]
  conflict: (currentVersion) -> ['c',currentVersion]
  reject: (msg) -> ['r',msg]
  bulk: (reply) -> [reply]

replies =
  Cookies: [
    'ok'
  ]

  Create: [
    'ok'
    'update'
    'reject'
  ]

  Read: [
    'ok'
    'doc'
    'reject'
    'bulk'
  ]

  Update: [
    'ok'
    'update'
    'conflict'
    'reject'
  ]

  Delete: [
    'ok'
    'reject'
  ]

  Run: [
    'ok'
    'doc'
    'update'
    'conflict'
    'reject'
  ]

  Distinct: [
    'doc'
    'reject'
  ]

for type, methodNames of replies
  module.exports[type] = clazz = (@cb) ->
  for name in methodNames
    do (clazz,name) ->
      clazz[name] = methods[name]
      clazz.prototype[name] = ->
        @cb.apply null, clazz[name].apply(null, arguments)
        @cb = undefined
        return

# Read.doc has to be treated separately -- the database can call doc with an array full documents but we only want to send arrays of document ids over the wire
module.exports.Read.prototype.doc = (docs) ->
  if Array.isArray docs
    newDocs = []
    newDocs[i] = doc._id.toString() for doc,i in docs
    docs = newDocs
  @cb.apply null, methods.doc(docs)
  @cb = undefined
