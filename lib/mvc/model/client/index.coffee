OJSON = require '../../../utils/ojson'
diff = require '../../../utils/diff'
clone = require '../../../utils/clone'

ObjectID = global.mongo.ObjectID
OJSON.register 'ObjectID': ObjectID
clone.register ObjectID, (other) -> new ObjectID(other.toString())

DBRef = global.mongo.DBRef
OJSON.register 'DBRef': DBRef
# for consistency with mongodb's existing toJSON implementation
DBRef.prototype.toJSON = ->
  "$ref": @namespace
  "$id": @oid
DBRef.fromJSON = (obj) ->
  new DBRef obj['$ref'], obj['$id']

clone.register DBRef, (other) -> new DBRef(other.namespace, other.oid)

diff.register DBRef,
  ((from, to, options) ->
    unless to instanceof DBRef
      coll = to.coll
      id = to.id?.toString()
      to = {namespace: coll, oid: id} if id and typeof coll is 'string'

    return false if to.namespace is from.namespace and to.oid is from.oid
    [{'o':1, 'v':to}]
  ), ((obj, diff, options) -> obj['v'])

module.exports = undefined
