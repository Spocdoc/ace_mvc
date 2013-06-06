Doc = require '../db/doc'
Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
ObjectID = global.mongo.ObjectID
Listener = require '../events/listener'
{include,extend} = require '../mixin'
clone = require '../clone'
diff = require '../diff'
patchOutlets = require '../diff/to_outlets'
debug = global.debug 'ace:mvc:model'
DBRef = global.mongo.DBRef
Registry = require '../registry'

class Model
  include Model, Listener
  @name = 'Model'

  @add: (coll) -> return this

  @get: (coll, id) ->
    #TODO

  constructor: (@db, @coll, id, spec) ->
    @_outlets = {}
    @_pushers = []
    @_ops = []
    @_updater = new Outlet =>
      return unless (ops = @_ops).length
      @_ops = []
      @doc.update ops
      return

    @_patchRegistry = new Registry
    @_patchRegistry.add DBRef,
      translate: (d, o) => @newModel d.namespace, d.oid

    @doc = @db.coll(@coll).read id, spec

    @listenOn @doc, 'reject', @serverReject
    @listenOn @doc, 'delete', @serverDelete

    if spec
      @_builders = []
      @doc.on 'idle', @_notifyBuilders, this
      @doc.create()

    else unless @doc.doc['_v'] > 0
      @_builders = []
      @doc.read()

    @id = @doc.id
    @copy = clone(@doc.doc)

    @listenOn @doc, 'update', @serverUpdate

    # 'reject'
    # 'conflict'
    # 'delete'
    # 'undelete'

  onbuilt: (cb) ->
    if @_builders
      debug "added waiting onbuilt cb"
      @_builders.push cb
    else
      debug "onbuilt returns immediately"
      if @doc._deleted
        cb 'delete'
      else if @doc.rejected?
        cb @doc.rejected
      else if @doc.conflicted?
        cb @doc.conflicted
      else
        cb()
    return

  get: (key) ->
    [path...,key] = key.split '.'
    o = @_outlets
    d = @copy

    # TODO strictly speaking this behavior of navigating transparently through a DBRef is inconsistent
    for p,i in path
      d = d[p] ||= {}
      if d instanceof DBRef
        model = @newModel d.namespace, d.oid
        return model.get path[(i+1)..].concat(key).join('.')
      o = o[p] ||= {}

    o = o[key] ||= {}
    d = d[key]

    unless o['_']
      if d instanceof DBRef
        d = @newModel d.namespace, d.oid
      else
        d = clone d

      o['_'] = new Outlet d, silent: true
      @_configureOutlet path.concat(key), o['_']

    o['_']

  toString: ->
    "#{@constructor.name} [#{@id}]"

  _delete: -> @doc.delete()

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
      patchOutlets @_outlets, ops, @copy, @_patchRegistry
    @_notifyBuilders() if @_builders
    return

  _configureOutlet: (path, outlet) ->
    @_pushers.push pusher = new Outlet (=>
      if ops = diff(@copy, outlet._value, path: path)
        @copy = diff.patch @copy, ops

        # update descendant outlets whose value may have changed because of this change
        # patchOutlets @_outlets, ops, @copy

        @_ops.push ops...
        pusher.modified()
    ), silent: true

    outlet.outflows.add pusher
    pusher.outflows.add @_updater
    outlet

  _notifyBuilders: (msg) ->
    debug "#{@} notifying builders"
    @doc.off 'idle', @_notifyBuilders, this
    builders = @_builders
    delete @_builders
    cb msg for cb in builders
    return


module.exports = Model

# patch uses clone to patch the @copy. If any field contains another model, it
# should instead clone it as a DBRef. diff for objects also uses clone. so the
# ops from @_pushers will never contain a model instance, only DBRefs
clone.register Model, (model) -> new DBRef model.coll, model.id

