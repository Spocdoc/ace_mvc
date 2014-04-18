require './register'
Base = require '../base'
Configs = require '../configs'
mongodb = require 'mongo-fork'
ObjectID = mongodb.ObjectID
DBRef = mongodb.DBRef
{Registry, queue, makeId} = require 'lodash-fork'
diff = require 'diff-fork'
clone = require 'diff-fork/clone'
OJSON = require 'ojson'
Outlet = require 'outlet'
Query = require './query'
Reject = require 'ace_mvc/lib/error/reject'
Conflict = require 'ace_mvc/lib/error/conflict'
_ = require 'lodash-fork'
Emitter = require 'events-fork/emitter'
patchOutlets = diff.toOutlets
debug = global.debug 'ace:mvc:model'
debugError = global.debug 'error'
debugSock = global.debug 'ace:sock'
autoResolve = require 'diff-fork/conflict'

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


module.exports = class ModelBase extends Base
  @configs = new Configs

  @attachSocketHandlers: (ace) ->
    sock = ace.sock

    sock.on 'create', (coll, doc) =>
      debug "got create on #{coll}, #{doc['_id']}"
      (@[coll].models[doc['_id']] || new @[coll] doc['_id']).serverCreate doc
      return

    sock.on 'update', (coll, id, version, ops) =>
      debug "got update on #{coll}, #{id}"
      if model = @[coll].models[id]
        model.serverUpdate version, ops
      return

    sock.on 'delete', (coll, id) =>
      debug "got delete on #{coll}, #{id}"
      model.serverDelete() if model = @[coll].models[id]
      return

    return

  @init: (ace, json) ->
    _this = this
    sock = ace.sock

    for type, config of @configs.configs
      @[type] = class Model extends @[type]
        _type = type # to capture the variable for below
        _.extend this, Emitter

        @models: {}
        @queryCache: {}
        @aceType: _type
        @sock: sock
        sock: sock
        aceParent: ace

        Model: _this
        'Model': _this

        @Query = @['Query'] = (spec, limit, sort) ->
          new Query _this[_type], spec, limit, sort

    @['reread'] = ->
      for type of @configs.configs
        clazz = @[type]
        ids = []
        versions = []
        docs = {}
        i = 0
        for id, model of clazz.models when model.canRead()
          ids[i] = id
          versions[i] = model.clientDoc?['_v'] || 0
          docs[id] = clone model.clientDoc
          ++i
        if ids[0]
          do (clazz, docs, ids) ->
            sock.emit 'read', type, ids, versions, (err, reply) ->
              if err?
                clazz.models[id].handleRead err for id in ids
              else
                for id, args of reply
                  clazz.models[id].handleRead args[0], args[1]
              clazz.emit 'reread'
              return
        else # emit the event anyway -- if no docs, queries still need to refresh
          clazz.emit 'reread'
      return

    @toJSON = ->
      docs = {}
      for type of @configs.configs
        models = []; i = 0
        models[i++] = serverDoc for id, model of @[type].models when serverDoc = model.serverDoc

        queryCache = {}
        for hash, {ids,distinct} of @[type].queryCache
          queryCache[hash] =
            'i': ids
            'd': distinct
          ++i

        if i
          docs[type] =
            'm': models
            'q': queryCache
      OJSON.toOJSON docs

    @clearQueryCache = ->
      @[type].queryCache = {} for type of @configs.configs
      Query.useBootCache = 0
      return

    if json
      for type, obj of OJSON.fromOJSON json
        for doc in obj['m']
          model = new @[type] doc['_id'], doc
          model.serverDoc = clone doc
        @[type].queryCache[hash] = {ids,distinct} for hash, {'i':ids,'d':distinct} of obj['q']
      @['reread']()

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
    if id
      (model = new this id).read() unless model = @models[id]
      model

  @['isValidId'] = do ->
    regex = /^[0-9a-f]{24}$/
    (id) -> regex.test ''+id

  constructor: (id, clientDoc) ->
    # this is for patching the serverDoc with DBRefs instead of models. clone calls it
    return new DBRef @aceType, new ObjectID(id.id) if id instanceof @constructor

    throw new Error "id is required in model constructor" unless id

    models = @constructor.models
    return model if model = models[id]
    models[id] = this

    super()

    try
      id = new ObjectID id unless id instanceof ObjectID
    catch _error

    @id = id.toString()

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

    debug "Building #{@aceType}[#{@}]"
    Outlet.openBlock()
    prev = Outlet.auto; Outlet.auto = null
    try
      @_buildOutlets()
      @_runConstructors()
      @_setOutlets()
    finally
      Outlet.auto = prev
      Outlet.closeBlock()
    debug "done building #{@aceType}[#{@}]"

  create: ->
    return if @serverDoc
    return @_pending.set pending | CREATE_LATER if (pending = @_pending.value) & NOW
    @_pending.set pending | CREATE_NOW

    @clientDoc ||= '_id': @id
    @clientDoc['_v'] ||= 1
    clientDoc = clone @clientDoc
    @sock.emit 'create', @aceType, clientDoc, (err, version, ops) =>
      @handleCreate err, clientDoc, version, ops

  handleCreate: (err, doc, version, ops) ->
    @_pending.set @_pending.value & ~CREATE_NOW

    if err?
      @error.set "can't create"
    else
      @error.set ''
      @serverDoc = doc
      @serverUpdate version, ops if ops

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
    @sock.emit 'read', @aceType, @id, (clientDoc && clientDoc['_v']), (err, doc) =>
      @handleRead err, doc or clientDoc

  handleRead: (err, clientDoc) ->
    @_pending.set @_pending.value & ~READ_NOW

    if err?
      @serverDelete()
      @error.set "can't read"
    else
      @error.set ''
      @serverCreate clientDoc if clientDoc

    @_loop()
    return

  @prototype['serverCreate'] = @serverCreate = (doc) ->
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

    if @outgoing[0]
      @_conflict() # TODO
    else
      @patchClient diff @clientDoc, @serverDoc
    return

  patchClient: (ops) ->
    @clientDoc = diff.patch @clientDoc, ops
    @clientDoc['_v'] = @serverDoc['_v'] if present = !!@clientDoc
    @present.set present
    if @_outlets
      Outlet.openBlock()
      try
        patchOutlets @_outlets, ops, @clientDoc, @_patchRegistry
      finally
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
      return @create() unless pending & (CREATE_LATER | READ_LATER)

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

    @sock.emit 'update', @aceType, @id, @serverDoc['_v'], outgoing, (err, version, ops) =>
        @handleUpdate err, outgoing, version, ops
    return

  handleUpdate: (err, outgoing, version, ops) ->
    if err?
      if err instanceof Conflict
        if @serverDoc['_v'] > @clientDoc['_v']
          @_conflict() # TODO
        else
          outgoing.push @outgoing...
          @outgoing = outgoing
          @_pending.set @_pending.value & ~UPDATE_NOW
          @_loop()
      else
        if @outgoing[0]
          outgoing.push @outgoing...
          @outgoing = outgoing
          @_update()
        else
          @error.set "can't update"
          @patchClient diff @clientDoc, @serverDoc
          @_pending.set @_pending.value & ~UPDATE_NOW
          @_loop()
    else
      ++@serverDoc['_v']
      ++@clientDoc['_v']
      @serverDoc = diff.patch @serverDoc, outgoing

      if ops
        @_pending.set @_pending.value & ~UPDATE_NOW
        @serverUpdate version, ops
        unless @conflict.value
          @_pending.set @_pending.value | UPDATE_NOW
          @_update()
      else
        @_update()
    return

  serverUpdate: (version, ops) ->
    return unless @serverDoc
    if version?
      return if version < @serverDoc['_v']
      @incoming[version] = ops
    @_serverUpdate()

  _serverUpdate: ->
    return if (@_pending.value & NOW) or @conflict.value
    ops = @patchServer()
    if @outgoing[0]
      @_conflict @clientDoc, @outgoing, @serverDoc, ops
    else
      @patchClient ops
    return

  patchServer: ->
    a = []
    while (ops = @incoming[@serverDoc['_v']])?
      if ops
        a.push ops...
        @serverDoc = diff.patch @serverDoc, ops
      delete @incoming[@serverDoc['_v']]
      ++@serverDoc['_v']
    return a

  _conflict: (clientDoc, outgoing, serverDoc, incoming) ->
    # TODO shouldn't have doc1 check
    if clientDoc and ops = autoResolve clientDoc, outgoing, serverDoc, incoming
      @patchClient ops
      @outgoing = diff(@serverDoc, @clientDoc) || []
      true
    else
      if debug
        if global.alert
          alert "CONFLICT"
        else
          debugError "CONFLICT"
        debugger

      @conflict.set true
      @outgoing = []
      @runQueue?.clear()
      @_pending.set 0

      false

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
      @sock.emit 'delete', @aceType, @id, (err) => @handleDelete err
    return

  handleDelete: (err) ->
    if err?
      @error.set "can't delete"
      @patchClient diff @clientDoc, @serverDoc
      @_loop()
    else
      @serverDelete()
    return

  @prototype['serverDelete'] = @prototype.serverDelete = ->
    delete @serverDoc
    @['reset']()
    return

  'run': (name, arg, cb) ->
    return if @conflict.value
    if typeof arg is 'function'
      cb = arg
      arg = null
    @runQueue ||= queue()
    @runQueue [name, arg, cb] if name
    return @_pending.set pending | RUN_LATER if (pending = @_pending.value) & NOW
    @_pending.set pending | RUN_NOW
    @_run()

  @['run'] = (cmd, arg, cb) ->
    debug "running ",cmd,"on #{@aceType}..."
    @sock.emit 'run', @aceType, 0, 0, cmd, arg, =>
      debug "finished running ",cmd,"on #{@aceType}"
      cb?.apply this, arguments
      return

  _run: ->
    unless arr = @runQueue()
      @_pending.set @_pending.value & ~RUN_NOW
      @_loop()
      return

    [cmd, arg, cb] = arr

    debug "running ",cmd,"on #{@aceType}..."
    @sock.emit 'run', @aceType, @id, (@serverDoc?['_v'] || 0), cmd, arg, =>
      debug "finished running ",cmd,"on #{@aceType}"
      cb?.apply this, arguments
      @_run()
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
        @['run']()
      else if pending & UPDATE_LATER
        @update()
      else
        @serverUpdate()
    return

  get: (key) ->
    @_clientOps ||= []
    (@_clientUpdater = new Outlet).func = (=> @update @_clientOps?.splice(0,@_clientOps.length)) unless @_clientUpdater
    unless @_patchRegistry
      @_patchRegistry = new Registry
      @_patchRegistry.add DBRef,
        translate: (d, o) => @Model[d.namespace].read d.oid

    [path...,key] = key.split '.'
    o = @_outlets ||= {}
    d = @clientDoc

    for p,i in path
      d &&= d[p]
      o = o[p] ||= {}

    o = o[key] ||= {}
    d &&= d[key]

    unless o['_']
      if d instanceof DBRef
        d = @Model[d.namespace].read d.oid
      else if d instanceof ModelBase
        d
      else
        d = clone d

      outlet = o['_'] = new Outlet d
      path = path.concat key

      (@_pushers ||= []).push pusher = new Outlet
      pusher.func = (=>
        if @clientDoc and !@conflict.value and ops = diff(@clientDoc, outlet.value, path: path)
          @clientDoc = diff.patch @clientDoc, ops

          # update descendant outlets whose value may have changed because of this change
          patchOutlets @_outlets, ops, @clientDoc, @_patchRegistry

          @_clientOps.push ops...
          makeId()
        else
          pusher.value
      )

      outlet.addOutflow pusher
      pusher.addOutflow @_clientUpdater

    o['_']

  toString: -> @id
