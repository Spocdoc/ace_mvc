Doc = require '../db/doc'
Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
ObjectID = global.mongo.ObjectID
Emitter = require '../events/emitter'
Listener = require '../events/listener'
{include,extend} = require '../mixin'
clone = require '../clone'
diff = require '../diff'
patchOutlets = require '../diff/to_outlets'

class Model
  include Model, Emitter
  include Model, Listener

  @add: (coll) -> return this

  constructor: (@coll, @db, idOrSpec) ->
    if typeof idOrSpec is 'string' or idOrSpec instanceof ObjectID
      return exists if exists = @constructor[@coll][idOrSpec]
      @doc = @db.coll(@coll).read(idOrSpec)
    else
      @doc = @db.coll(@coll).create(idOrSpec)

    @id = @doc._id
    @copy = clone(@doc.doc)
    @constructor[@coll][@id] = this

    @_attach()
    @_outlets = {}
    @_pushers = {}
    @_ops = []
    @_updater = new Outlet =>
      return unless (ops = @_ops).length
      @_ops = []
      @doc.update ops
      return

  _attach: ->
    @doc ||= @db.coll(@coll).read(@id)
    @listenOn doc, 'update', @serverUpdate
    # 'reject'
    # 'conflict'
    # 'delete'
    # 'undelete'

  serverUpdate: (ops) ->
    @copy = diff.patch @copy, ops
    Cascade.Block =>
      patchOutlets ops, @_outlets, @copy

  _configureOutlet: (path, outlet) ->
    @_pushers.push pusher = new Oultet (=>
      ops = diff @doc, outlet._value, path: path
      @doc = diff.patch @doc, ops
      @_ops.push ops...
      pusher.modified()), silent: true

    outlet.outflows.add pusher
    pusher.outflows.add @_updater
    outlet

  get: (path, key) ->
    return this unless path

    path = path.concat(key) if key?
    o = @_outlets
    o = o[p] ||= {} for p in path
    return o._ if o._

    d = @copy
    `for (var i = 0, e = path.length-1; i < e; ++i) d = d[path[i]] || (d[path[i]] = {});`
    @configureOutlet(path, o._ = new Outlet(clone(d[path.length-1]),silent:true))


module.exports = Model
