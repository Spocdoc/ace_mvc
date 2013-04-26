class Snapshots extends Array
  @Compound = ->

  class @Snapshot

    syncTarget = (src, dst) ->
      for key, value of src when key[0] != '_' and !src.constructor.prototype[key]? and dst[key]?
        if not (value instanceof Snapshots.Compound)
          dst[key].sync(value)
        else
          syncTarget src[key], dst[key]
      return

    localPath: (arr) ->
      o = this
      for p in arr
        if not o[p]?
          o[p] = new Snapshots.Compound
        else if not {}.hasOwnProperty.call(o, p)
          o[p] = Object.create(parent = o[p])
          o[p]._parent = parent
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

    syncTarget: (dst) ->
      syncTarget this, dst

    # sets the path to undefined if it isn't own property
    noInherit: (path, key) ->
      [path..., key] = path if not key?
      o = @localPath(path)
      o[key] = undefined if !{}.hasOwnProperty.call(o, key)

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
      next._parent = parent
      @push next
    else
      @push new @snapshotFactory

module.exports = Snapshots

# add OJSON serialization functions
require('./snapshots_ojson')(Snapshots)
