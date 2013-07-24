ObjectID = global.mongo.ObjectID
DBRef = global.mongo.DBRef
Registry = require '../../utils/registry'
diff = require '../../utils/diff'
clone = require '../../utils/clone'
queue = require '../../utils/queue'
OJSON = require '../../utils/ojson'
Outlet = require '../../utils/outlet'
Query = require './query'
patchOutlets = diff.toOutlets

debug = global.debug 'ace:mvc'

configs = new (require('../configs'))
reserved = ['constructor','static']

NOW            = 0

CREATE_LATER   = 1 << 0
NOW           += 2 << 0
CREATE_NOW     = 3 << 0

READ_LATER     = 1 << 2
NOW           += 2 << 2
READ_NOW       = 3 << 2

UPDATE_LATER   = 1 << 4
NOW           += 2 << 4
UPDATE_NOW     = 3 << 4

DELETE_LATER   = 1 << 6
NOW           += 2 << 6
DELETE_NOW     = 3 << 6

RUN_LATER      = 1 << 8
NOW           += 2 << 8
RUN_NOW        = 3 << 8

OK_INCONSISTENT = 1 << 0
OK_NOAUTH       = 2 << 2
OK_CONFLICT     = 3 << 4


module.exports = class Model
  @name = 'Model'

  @add: (type, config) -> configs.add type, config

  @finish: ->
    configs.applyMixins()

    ModelBase = Model
    types = {}
    for type,config of configs.configs
      types[type] = class Model extends ModelBase
        coll: type
        _config: config

        @_applyStatic config
        @_applyMethods config
    ModelBase[k] = v for k, v of types
    return

  @init: (globals, sock, json) ->
    _this = this

    sock.on 'create', (coll, doc) =>
      doc = OJSON.fromOJSON doc
      if model = @[coll].models[doc._id]
        model.serverCreate doc
      else
        new @[coll] doc._id, doc
      return

    sock.on 'update', (coll, id, version, ops) =>
      if model = @[coll].models[id]
        model.serverUpdate version, OJSON.fromOJSON ops
      return

    sock.on 'delete', (coll, id) =>
      model.serverDelete() if model = @[coll].models[id]
      return

    for type, config of configs
      @[type] = class Model extends @[type]
        @models: {}
        sock: sock

        Model: _this
        'Model': _this

        _type = type # to capture the variable for below
        @Query = @['Query'] = (spec, limit, sort) ->
          new Query _this[_type], spec, limit, sort

        @prototype[k] = v for k,v of (@prototype.globals = globals).app

    if json
      for type, docs of obj
        ids = []
        versions = []
        clazz = @[type]
        for doc in docs when (new clazz doc._id, doc).canRead()
          ids.push doc._id
          versions.push doc._v
        do (clazz) ->
          sock.emit 'read', type, ids, versions, null, null, null, (code) ->
            if typeof code is 'object'
              Outlet.openBlock()
              (model = clazz.models[id]).handleRead.apply model, arr for id, arr of code
              Outlet.closeBlock()
            return

    @['reread'] = ->
      for type of configs
        clazz = @[type]
        ids = []
        versions = []
        for id, model of clazz.models when model.canRead()
          ids.push model.id
          versions.push model.clientDoc?._v || 0
        do (clazz) ->
          sock.emit 'read', type, ids, versions, null, null, null, (code) ->
            if typeof code is 'object'
              Outlet.openBlock()
              (model = clazz.models[id]).handleRead.apply model, arr for id, arr of code
              Outlet.closeBlock()
            return
      return
    return

  @toJSON: ->
    docs = {}
    for type of configs.configs
      models = docs[type] = []
      i = 0
      for id, model of @[type].models when serverDoc = model.serverDoc
        models[i++] = serverDoc
    OJSON.toOJSON docs

  @_applyStatic: (config) ->
    @[name] = fn for name, fn of config['static']
    return

  @_applyMethods: (config) ->
    @prototype[name] = method for name, method of config when not (name in reserved)
    return

  _applyConstructors: ->
    constructors = @_config['constructor']

    if Array.isArray constructors
      for constructor in constructors
        constructor.call this
    else
      constructors.call this

    return

  # id is optional
  @['create'] = @create = (id, spec) ->
    unless typeof id is 'string' or id instanceof ObjectID
      spec = id
      id = new ObjectID
    (model = new this id, spec).create() unless model = @models[id]
    model

  # can also call with an array of ids, optional array of versions and optional callback
  @['read'] = @read = (id) ->
    (model = new this id).read() unless model = @models[id]
    model

    type = @prototype.coll
    sock = @prototype.sock

    if typeof arg is 'string' or arg instanceof ObjectID
      (model = @models[arg] = new this arg).read() unless model = @models[arg]
      
    else if Array.isArray arg
      allVersions = arguments[1] || []
      ids = []
      versions = []
      i = 0

      for id,j in arg
        if (@models[id] ||= new this id).canRead()
          ids[i] = id
          versions[i] = allVersions[j]
          ++i

      sock.emit 'read', type, ids, versions, null, null, null, (code) =>
        if typeof code is 'object'
          Outlet.openBlock()
          (model = @models[id]).handleRead.apply model, arr for id, arr of code
          Outlet.closeBlock()
        return

    model

  @isValidId: do ->
    regex = /^[0-9a-f]{24}$/
    (id) -> !!(''+id).match regex

  constructor: (id, clientDoc) ->
    # this is for patching the serverDoc with DBRefs instead of models. clone calls it
    return new DBRef @coll, id.id if id instanceof @constructor

    models = @constructor.models
    return model if model = models[id]
    models[id] = this

    try
      id = new ObjectID id unless id instanceof ObjectID
    catch _error

    @id = id

    present = !!clientDoc
    @clientDoc = clientDoc || {}
    @clientDoc['_id'] = id
    @clientDoc['_v'] ||= 0

    @outgoing = [] # outgoing ops when pending
    @incoming = [] # incoming ops when pending

    @_pending = new Outlet 0
    @['pending'] = @pending = new Outlet => !!@_pending.value
    @_pending.addOutflow @pending

    @['present'] = @present = new Outlet present
    @['error'] = @error = new Outlet ''
    @['conflict'] = @conflict = new Outlet false

    debug "Building #{@}"
    Outlet.openBlock()
    prev = Outlet.auto; Outlet.auto = null
    try
      @_applyConstructors @_config
    finally
      Outlet.auto = prev
      Outlet.closeBlock()
    debug "done building #{@}"

  create: ->
    return if @serverDoc
    return @_pending.set pending | CREATE_LATER if (pending = @_pending.value) & NOW
    @_pending.set pending | CREATE_NOW

    @clientDoc ||= '_id': id
    @clientDoc['_v'] ||= 1
    clientDoc = clone @clientDoc
    @sock.emit 'create', @coll, OJSON.toOJSON(clientDoc), (code, msg) =>
      Outlet.openBlock()
      @handleCreate code, clientDoc, msg
      Outlet.closeBlock()

  handleCreate: (code, doc, msg) ->
    @_pending.set @_pending.value & ~CREATE_NOW

    if code is 'r'
      @error.set msg || "can't create"
    else
      @error.set ''
      @serverDoc = doc

    @_loop()
    return

  canRead: ->
    return if @conflict.value
    return @_pending.set pending | READ_LATER if (pending = @_pending.value) & NOW
    @_pending.set pending | READ_NOW
    true

  read: ->
    return unless @canRead()
    clientDoc = clone @clientDoc
    @sock.emit 'read', @coll, @id, (clientDoc && clientDoc['_v']), null, null, null, (code, arg) =>
      Outlet.openBlock()
      @handleRead code, arg, clientDoc
      Outlet.closeBlock()

  handleRead: (code, arg, clientDoc) ->
    @_pending.set @_pending.value & ~READ_NOW

    if code is 'r'
      @serverDelete()
      @error.set arg || "can't read"
    else
      @error.set ''
      @serverCreate if code is 'd' then OJSON.fromOJSON(arg) else clientDoc

    @_loop()
    return

  serverCreate: (doc) ->
    return if @conflict.value

    newVersion = doc['_v']

    if @serverDoc
      oldVersion = @serverDoc['_v']
      return if newVersion <= oldVersion

      incoming = []
      len = @incoming.length
      `for (var i = newVersion; i < len; ++i) incoming[i] = this.incoming[i];`
      @incoming = incoming

    @serverDoc = doc

    return if @clientDoc and @clientDoc['_v'] is newVersion

    if @outgoing.length
      @_conflict()
    else
      @patchClient diff @clientDoc, @serverDoc
    return

  patchClient: (ops) ->
    @clientDoc = diff.patch @clientDoc, ops
    @present.set !!@clientDoc
    if @_outlets
      Outlet.openBlock()
      patchOutlets @_outlets, ops, @clientDoc, @_patchRegistry
      Outlet.closeBlock()
    return

  'reset': ->
    @error.set ''
    @conflict.set false
    @outbound = []
    @patchClient diff @clientDoc, @serverDoc
    return

  # never called if conflicted
  update: (ops) ->
    pending = @_pending.value
    unless @serverDoc
      return @create unless pending & (CREATE | READ)

    @outgoing.push ops... if ops
    return @_pending.set pending | UPDATE_LATER if pending & NOW

    @_pending.set pending | UPDATE_NOW
    @_update()
    return

  _update: ->
    outgoing = @outgoing
    @outgoing = []
    unless outgoing[0]
      @_pending.set @_pending.value & ~UPDATE_NOW
      @_loop()
      return

    @sock.emit 'update', @coll, @id, @serverDoc['_v'], OJSON.toOJSON(outgoing), (code, arg1, arg2, outgoing) =>
      Outlet.openBlock()
      @handleUpdate code, arg1, arg2, outgoing
      Outlet.closeBlock()
    return

  handleUpdate: (code, arg1, arg2, outgoing) ->
    if code is 'r'
      if @outgoing.length
        outgoing.push @outgoing...
        @outgoing = outgoing
        @_update()
      else
        @error.set arg1 || "can't update"
        @patchClient diff @clientDoc, @serverDoc
        @_pending.set @_pending.value & ~UPDATE_NOW
        @_loop()
    else if code is 'c'
      if @serverDoc['_v'] > @clientDoc['_v']
        @_conflict()
      else
        outgoing.push @outgoing...
        @outgoing = outgoing
        @_pending.set @_pending.value & ~UPDATE_NOW
        @_loop()
    else
      ++@serverDoc['_v']
      @serverDoc = diff.patch @serverDoc, outgoing
      @serverUpdate arg1, OJSON.fromOJSON(arg2) if code is 'u'
      @_update()
    return

  serverUpdate: (version, ops) ->
    return unless @serverDoc
    if version?
      return if version < @serverDoc['_v']
      @incoming[version] = ops
    @_serverUpdate()

  _serverUpdate: ->
    return if @_pending.value or @conflict.value
    ops = @patchServer()
    if @outgoing
      @_conflict()
    else
      @patchClient ops
    return

  patchServer: ->
    a = []
    while ops = @incoming[@serverDoc['_v']]
      a.push ops...
      delete @incoming[@serverDoc['_v']]
      @serverDoc = diff.patch @serverDoc, ops
      ++@serverDoc['_v']
    return a

  _conflict: ->
    @conflict.set true
    @outgoing = []
    @runQueue.clear()
    @_pending.set 0
    return

  'resolveConflict': ->
    return unless @serverDoc['_v'] > @clientDoc['_v']
    @conflict.set false
    @clientDoc['_v'] = @serverDoc['_v']
    @update diff @serverDoc, @clientDoc
    return

  'delete': ->
    return @_pending.set pending | DELETE_LATER if (pending = @_pending.value) & NOW
    @_pending.set pending | DELETE_NOW

    unless @serverDoc
      @serverDelete()
    else
      @patchClient diff @clientDoc, null
      @sock.emit 'delete', @coll, @id, (code, msg) =>
        Outlet.openBlock()
        @handleDelete code, msg
        Outlet.closeBlock()
    return

  handleDelete: (code, msg) ->
    if code is 'r'
      @error.set msg || "can't delete"
      @patchClient diff @clientDoc, @serverDoc
      @_loop()
    else
      @serverDelete()
    return

  serverDelete: ->
    delete @serverDoc
    @_pending.set @_pending.value & NOW
    @['reset']()
    return

  'run': (name, args, cb) ->
    return if @conflict.value or !@serverDoc
    @runQueue ||= queue()
    @runQueue [name, args, cb] if name
    return @_pending.set pending | RUN_LATER if (pending = @_pending.value) & NOW
    @_pending.set pending | RUN_NOW
    @_run()

  _run: ->
    unless arr = @runQueue()
      @_pending.set @_pending.value & ~RUN_NOW
      @_loop()
      return

    [cmd, args, cb] = arr

    @sock.emit 'run', @coll, @id, @serverDoc['_v'], cmd, OJSON.toOJSON(args), (code) =>
      cb.apply this, arguments
      @_run()
      return
    return

  _loop: ->
    pending = @_pending.value

    if pending & DELETE_LATER
      @delete()
    else if pending & CREATE_LATER
      @create()
    else if pending & READ_LATER
      @read()
    else unless @conflict.value
      if pending & RUN_LATER
        @run()
      else if pending & UPDATE_LATER
        @update()
      else
        @serverUpdate()
    return

  get: (key) ->
    @_clientOps ||= []
    (@_clientUpdater = new Outlet).func = (=> @update @_clientOps?.splice(0)) unless @_clientUpdater
    unless @_patchRegistry
      @_patchRegistry = new Registry
      @_patchRegistry.add DBRef,
        translate: (d, o) => @Model[d.namespace].read d.oid

    [path...,key] = key.split '.'
    o = @_outlets ||= {}
    d = @clientDoc

    # TODO strictly speaking this behavior of navigating transparently through a DBRef is inconsistent
    for p,i in path
      d = d[p] ||= {}
      if d instanceof DBRef
        model = @Model[d.namespace].read d.oid
        return model.get path[(i+1)..].concat(key).join('.')
      o = o[p] ||= {}

    o = o[key] ||= {}
    d = d[key]

    unless o['_']
      if d instanceof DBRef
        d = @Model[d.namespace].read d.oid
      else
        d = clone d

      outlet = o['_'] = new Outlet d
      path = path.concat key

      (@_pushers ||= []).push pusher = new Outlet
      pusher.func = (=>
        if !@conflict.value and ops = diff(@clientDoc, outlet.value, path: path)
          @clientDoc = diff.patch @clientDoc, ops

          # update descendant outlets whose value may have changed because of this change
          # patchOutlets @_outlets, ops, @clientDoc

          @_clientOps.push ops...
          pusher.modified()
        return
      )

      outlet.addOutflow pusher
      pusher.addOutflow @_clientUpdater

    o['_']

  toString: -> "Model[#{@coll}][#{@id}][#{@clientDoc?['_v']}]"
