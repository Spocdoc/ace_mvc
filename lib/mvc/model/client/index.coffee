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
  "$id": OJSON.toOJSON @oid
DBRef.fromJSON = (obj) ->
  new DBRef obj['$ref'], obj['$id']

clone.register DBRef, (other) -> new DBRef(other.namespace, other.oid)

diff.register DBRef,
  ((from, to, options) ->
    unless to instanceof DBRef
      return false unless to.id and to.coll
      to = new DBRef to.coll, if to.id instanceof ObjectID then to.id else new ObjectID(to.id)

    return false if to.namespace is from.namespace and to.oid?.toString() is from.oid?.toString()
    [{'o':1, 'v':to}]
  ), ((obj, diff, options) -> diff[0]['v'])

module.exports = undefined
