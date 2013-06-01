Doc = require '../db/doc'
Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
ObjectID = global.mongo.ObjectID
Emitter = require '../events/emitter'
Snapshots = require '../snapshots/snapshots'
Listener = require '../events/listener'
{include,extend} = require '../mixin'
clone = require '../clone'
diff = require '../diff'
patchOutlets = require '../diff/to_outlets'
debug = global.debug 'ace:mvc:model'

class Model
  include Model, Emitter
  include Model, Listener
  @name = 'Model'

  @add: (coll) -> return this

  constructor: (@coll, @db, idOrSpec) ->
    if typeof idOrSpec is 'string' or idOrSpec instanceof ObjectID
      @doc = @db.coll(@coll).read(idOrSpec)
    else
      @doc = @db.coll(@coll).create(idOrSpec)

    @id = @doc.id
    @copy = clone(@doc.doc)

    @_onload = [] unless @doc.loaded
    @_attach()
    @_outlets = {}
    @_pushers = []
    @_ops = []
    @_updater = new Outlet =>
      return unless (ops = @_ops).length
      @_ops = []
      @doc.update ops
      return

  onload: (cb) ->
    debug "added onload cb. loaded: [#{@doc.loaded}]"
    if @_onload
      @_onload.push cb
    else
      if @doc._deleted
        cb 'delete'
      else if @doc.rejected?
        cb @doc.rejected
      else
        cb()
    return

  _attach: ->
    @doc ||= @db.coll(@coll).read(@id)
    @listenOn @doc, 'reject', @serverReject
    @listenOn @doc, 'delete', @serverDelete
    # 'reject'
    # 'conflict'
    # 'delete'
    # 'undelete'
    @listenOn @doc, 'update', @serverUpdate

  serverDelete: ->
    debug "serverDelete for #{@}"
    if @_onload
      cb('delete') for cb in @_onload
      delete @_onload
    return

  serverReject: (err) ->
    debug "serverReject for #{@}"
    if @_onload
      cb(err) for cb in @_onload
      delete @_onload
    return

  serverUpdate: (ops) ->
    debug "serverUpdate for #{@}"
    @copy = diff.patch @copy, ops
    Cascade.Block =>
      patchOutlets @_outlets, ops, @copy

    if @_onload
      cb() for cb in @_onload
      delete @_onload

    return

  _configureOutlet: (path, outlet) ->
    @_pushers.push pusher = new Outlet (=>
      if ops = diff(@copy, outlet._value, path: path)
        @copy = diff.patch @copy, ops
        @_ops.push ops...
        pusher.modified()
    ), silent: true

    outlet.outflows.add pusher
    pusher.outflows.add @_updater
    outlet

  get: (path, key) ->
    return this unless path
    path = Snapshots.getPath path,key
    o = @_outlets
    o = o[p] ||= {} for p in path
    return o._ if o._

    d = @copy
    `for (var i = 0, e = path.length-1; i < e; ++i) d = d[path[i]] || (d[path[i]] = {});`
    @_configureOutlet(path, o._ = new Outlet(clone(d[path[path.length-1]]),silent:true))

  toString: ->
    "#{@constructor.name} [#{@id}]"


module.exports = Model
