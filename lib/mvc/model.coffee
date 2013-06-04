Doc = require '../db/doc'
Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
ObjectID = global.mongo.ObjectID
Snapshots = require '../snapshots/snapshots'
Listener = require '../events/listener'
{include,extend} = require '../mixin'
clone = require '../clone'
diff = require '../diff'
patchOutlets = require '../diff/to_outlets'
debug = global.debug 'ace:mvc:model'
DBRef = global.mongo.DBRef

class Model
  include Model, Listener
  @name = 'Model'

  @add: (coll) -> return this

  @get: (coll, id) ->
    #TODO

  constructor: (@db, @coll, id, spec) ->
    unless spec
      @doc = @db.coll(@coll).read(id)
      @_builders = [] unless @doc.doc._v > 0
    else
      @doc = @db.coll(@coll).create(spec, id)
      @_builders = []
      @doc.on 'idle', @_notifyBuilders, this

    @id = @doc.id
    @copy = clone(@doc.doc)

    @_attach()
    @_outlets = {}
    @_pushers = []
    @_ops = []
    @_updater = new Outlet =>
      return unless (ops = @_ops).length
      @_ops = []
      @doc.update ops
      return

  onbuilt: (cb) ->
    debug "added onbuilt cb"
    if @_builders
      @_builders.push cb
    else
      if @doc._deleted
        cb 'delete'
      else if @doc.rejected?
        cb @doc.rejected
      else if @doc.conflicted?
        cb @doc.conflicted
      else
        cb()
    return

  get: (path, key) ->
    return this unless path
    path = Snapshots.getPath path,key
    o = @_outlets
    o = o[p] ||= {} for p in path

    unless o._
      d = @copy
      `for (var i = 0, e = path.length-1; i < e; ++i) d = d[path[i]] || (d[path[i]] = {});`
      d = d[path[path.length-1]]

      if d instanceof DBRef
        d = @newModel d.namespace, d.oid
      else
        d = clone d

      o._ = new Outlet d, silent: true
      @_configureOutlet path, o._

    o._

  toString: ->
    "#{@constructor.name} [#{@id}]"

  _delete: -> @doc.delete()

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
    @_notifyBuilders 'delete' if @_builders
    return

  serverReject: (err) ->
    debug "serverReject for #{@}"
    @_notifyBuilders err if @_builders
    return

  serverUpdate: (ops) ->
    debug "serverUpdate for #{@}"
    @copy = diff.patch @copy, ops
    Cascade.Block =>
      patchOutlets @_outlets, ops, @copy
    @_notifyBuilders() if @_builders
    return

  newModel: (coll, id, spec) -> new @constructor @db, coll, id, spec

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

  _notifyBuilders: (msg) ->
    @doc.off 'idle', @_notifyBuilders, this
    builders = @_builders
    delete @_builders
    cb msg for cb in builders
    return


module.exports = Model

# patch uses clone to patch the @copy. If any field contains another model, it
# should instead clone it as a DBRef. diff for objects also uses clone. so the
# ops from @_pushers will never contain a model instance, only DBRefs
clone.register Model, (model) -> new DBRef model.coll.name, model.id

