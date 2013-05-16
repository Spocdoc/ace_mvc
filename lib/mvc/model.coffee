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

  @add: (coll) ->
    @[coll] = (idOrSpec) ->
      new @(coll, idOrSpec)
    return this

  constructor: (@db, @coll, idOrSpec) ->
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
    @_ocalc = []
    @_ops = new Outlet []
    @_ops.outflows.add =>
      return unless (ops = @_ops.get()).length
      @_ops.set([])
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
    fn = =>
      ops = diff @doc, outlet.get(), path: path
      @doc = diff.patch @doc, ops
      @_ops.push ops...

    @_ocalc.push calc = new Outlet fn, silent: true
    outlet.outflows.add calc
    calc.outflows.add @_ops
    outlet

  get: (path, key) ->
    path = path.concat(key) if key?
    o = @_outlets
    o = o[p] ||= {} for p in path
    return o._ if o._

    d = @copy
    `for (var i = 0, e = path.length-1; i < e; ++i) d = d[path[i]] || (d[path[i]] = {});`
    @configureOutlet(path, o._ = new Outlet(clone(d[path.length-1]),silent:true))


module.exports = Model
