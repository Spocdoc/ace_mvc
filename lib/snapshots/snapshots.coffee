class Snapshots
  @Compound = ->

  @getPath = (path) ->
    if typeof path is 'string'
      path.split '/'
    else
      path

  class @Snapshot

    syncTarget = (src, dst) ->
      syncTarget(src[k], dst[k]) for k of src when k.charAt(0) != '_' and !src.constructor.prototype[k]? and dst[k]
      dst['_'].sync src['_'] if src.hasOwnProperty '_'
      return

    localPath: (arr) ->
      o = this
      for p in arr
        unless o[p]
          o[p] = new Snapshots.Compound
        else unless o.hasOwnProperty p
          o[p] = Object.create(parent = o[p])
          o[p]['_parent'] = parent
        o = o[p]
      return o

    ensurePath: (arr) ->
      o = this
      for p in arr
        o = (o[p] ||= new Snapshots.Compound)
      return o

    get: (arr) ->
      o = this
      for p in arr
        return unless o = o[p]
      return o['_']

    @each: (o,fn) ->
      @each(v, fn) for k, v of o when k.charAt(0) != '_' and !o.constructor.prototype[k]?
      fn o['_'] if o.hasOwnProperty('_')
      return

    each: (arr, fn) ->
      o = this
      for p in arr
        return unless o = o[p]
      Snapshots.Snapshot.each(o, fn)
      return

    syncTarget: (dst) ->
      syncTarget this, dst

    # sets the path to null (NOT undefined) if it isn't own property
    # null is used because it's too difficult to serialize undefined values over JSON
    noInherit: (path) ->
      path = Snapshots.getPath path
      o = @localPath path
      if !o.hasOwnProperty('_')
        prev = o['_']
        o['_'] = null
        return prev

    _inherit: ->
      Object.create(this)

  snapshotFactory: -> new Snapshots.Snapshot

  constructor: (arg) ->
    if arg?
      @array = arg
    else
      @array = []
      @push()

  splice: ->
    @array.splice.apply(@array, arguments)

  push: (arg) ->
    return @array.push(arg) if arguments.length
    if len = @array.length
      parent = @array[len-1]
      next = parent._inherit()
      next['_parent'] = parent
      @array.push next
    else
      @array.push new @snapshotFactory

module.exports = Snapshots

# add OJSON serialization functions
require('./snapshots_ojson')(Snapshots)
