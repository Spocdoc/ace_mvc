
class Snapshots extends Array
  @Compound = ->

  @getPath = (path, key) ->
    if typeof path is 'string'
      path = path.split '/'
    if key?
      path = path.concat()
      path.push key
    path

  @getPathKey = (path, key) ->
    path = @getPath(path)
    [path..., key] = path if not key?
    [path, key]

  class @Snapshot

    syncTarget = (src, dst) ->
      # sync nested keys first then yours
      for k, v of src when k[0] != '_' and !src.constructor.prototype[k]? and dst[k]?
        continue unless v instanceof Snapshots.Compound
        syncTarget src[k], dst[k]
      for k, v of src when k[0] != '_' and !src.constructor.prototype[k]? and dst[k]?
        continue if v instanceof Snapshots.Compound
        dst[k].sync(v)
      return

    localPath: (arr) ->
      o = this
      for p in arr
        if not o[p]?
          o[p] = new Snapshots.Compound
        else if not {}.hasOwnProperty.call(o, p)
          o[p] = Object.create(parent = o[p])
          o[p]['_parent'] = parent
        o = o[p]
      return o

    ensurePath: (arr) ->
      o = this
      for p in arr
        o[p] = new Snapshots.Compound if not o[p]?
        o = o[p]
      return o

    get: (arr) ->
      o = this
      for p in arr
        return undefined if not o[p]?
        o = o[p]
      return o

    @each: (o,fn) ->
      for k, v of o when k[0] != '_' and !o.constructor.prototype[k]?
        if v instanceof Snapshots.Compound
          @each v, fn
        else
          fn(v)
      return

    each: (arr, fn) ->
      return unless (o = @get(arr))? and o instanceof Snapshots.Compound
      Snapshots.Snapshot.each(o, fn)
      return

    syncTarget: (dst) ->
      syncTarget this, dst

    # sets the path to null (NOT undefined) if it isn't own property
    # null is used because it's too difficult to serialize undefined values over JSON
    noInherit: (path, key) ->
      [path, key] = Snapshots.getPathKey path, key
      o = @localPath(path)
      if !{}.hasOwnProperty.call(o, key)
        prev = o[key]
        o[key] = null
        return prev

    _inherit: ->
      Object.create(this)

  snapshotFactory: -> new Snapshots.Snapshot

  constructor: ->
    @push()

  push: ->
    return super if arguments.length
    len = @length
    if len
      parent = @[len-1]
      next = parent._inherit()
      next['_parent'] = parent
      super next
    else
      super new @snapshotFactory

module.exports = Snapshots

# add OJSON serialization functions
require('./snapshots_ojson')(Snapshots)
