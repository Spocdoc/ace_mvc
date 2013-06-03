{include, extend} = require '../../mixin'
OJSON = require '../../ojson'
diff = require '../../diff'
clone = require '../../clone'
{'diff': diffObj, 'patch': patchObj} = require('../../diff/object')


OJSON.register 'ObjectID': global.mongo.ObjectID

DBRef = global.mongo.DBRef
OJSON.register 'DBRef': DBRef
extend DBRef, OJSON.copyKeys
clone.register DBRef, (other) -> new DBRef(other.namespace, other.oid)

hasOwn = {}.hasOwnProperty
diff.register DBRef,
  ((from, to, options) ->
    if to instanceof DBRef
      diffObj from, to, options
    else if (coll = doc.coll)?
      coll = coll.name unless typeof coll is 'string'
      id = doc.id?.toString()
      return false unless id and typeof coll is 'string'
      to = {namespace: coll, oid: id}
      diffObj from, to, options
    else
      false
    ),
  patchObj

