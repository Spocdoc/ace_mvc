OJSON = require 'ojson'
diff = require 'diff-fork'
clone = require 'diff-fork/clone'
Query = require './query'

mongodb = require 'mongo-fork'
ObjectID = mongodb.ObjectID
OJSON.register 'ObjectID': ObjectID
clone.register ObjectID, (other) -> new ObjectID(other.toString())

DBRef = mongodb.DBRef
OJSON.register 'DBRef': DBRef
# for consistency with mongodb's existing toJSON implementation
DBRef.prototype.toJSON = ->
  "$ref": @namespace
  "$id": OJSON.toOJSON @oid
DBRef.fromJSON = (obj) ->
  new DBRef obj['$ref'], obj['$id']

clone.register DBRef, (other) -> new DBRef(other.namespace, other.oid)

dbRefDiff = (from, to, options) ->
  unless to instanceof DBRef
    return false unless to.id and to.aceType
    to = new DBRef to.aceType, if to.id instanceof ObjectID then to.id else new ObjectID(to.id)

  return false if to.namespace is from.namespace and to.oid?.toString() is from.oid?.toString()
  [{'o':1, 'v':to}]

dbRefDiff.patch = (obj, diff, options) -> diff[0]['v']

diff.register DBRef, dbRefDiff
