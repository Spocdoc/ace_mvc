ObjectID = global.mongo.ObjectID
DBRef = global.mongo.DBRef
Registry = require '../../utils/registry'
diff = require '../../utils/diff'
clone = require '../../utils/clone'
debug = global.debug 'ace:mvc:model'
debugMvc = global.debug 'ace:mvc'
queue = require '../../utils/queue'

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

module.exports = (pkg) ->

  OJSON = pkg.ojson || require('../../utils/ojson')(pkg)
  cascade = pkg.cascade || require('../../cascade')(pkg)
  mvc = pkg.mvc

  patchOutlets = diff.toOutlets
  Cascade = cascade.Cascade
  Outlet = cascade.Outlet

  sock = pkg.socket

  sock.on 'create', (coll, doc) ->
    doc = OJSON.fromOJSON doc
    if model = mvc.Model[coll].models[doc._id]
      model.serverCreate doc
    else
      new mvc.Model[coll] doc._id, doc
    return

  sock.on 'update', (coll, id, version, ops) ->
    if model = mvc.Model[coll].models[id]
      model.serverUpdate version, OJSON.fromOJSON ops
    return

  sock.on 'delete', (coll, id) ->
    model.serverDelete() if model = mvc.Model[coll].models[id]
    return

  Query = require('./query')(pkg)

  mvc.Global.prototype['Model'] = mvc.Model = class Model extends mvc.Global
    @name = 'Model'

    @fromJSON: (obj) ->
      for type, docs of obj
        ids = []
        versions = []
        for doc,i in docs
          (new mvc.Model[type] doc._id, doc).read true
          ids[i] = doc._id
          versions[i] = doc._v
        mvc.Model[type].read ids, versions
      return

    @toJSON: ->
      docs = {}
      for type of configs.configs
        models = docs[type] = []
        i = 0
        for id, model of mvc.Model[type].models when serverDoc = model.serverDoc
          models[i++] = serverDoc
      OJSON.toOJSON docs

    @_applyStatic: (config) ->
      @[name] = fn for name, fn of config['static']
      return

    @_applyMethods: (config) ->
      @prototype[name] = method for name, method of config when not (name in reserved)
      return

    _applyConstructors: (config) ->
      constructors = config['constructor']

      if Array.isArray constructors
        for constructor in constructors
          constructor.call this
      else
        constructors.call this

      return

    constructor: (id, @clientDoc={}) ->
      try
        id = new ObjectID id unless id instanceof ObjectID
      catch _error

      @id = id

      @clientDoc['_id'] = id
      @clientDoc['_v'] ||= 0

      @outgoing = [] # outgoing ops when pending
      @incoming = [] # incoming ops when pending

      @runQueue = queue()

      @['pending'] = @pending = new Outlet 0
      @['reject'] = @reject = new Outlet ''
      @['conflict'] = @conflict = new Outlet false

    onServerDoc: (cb) ->
      return cb this if @serverDoc
      (@_onServerDoc ||= []).push cb

    _notifyServerDoc: ->
      cb this for cb in @_onServerDoc
      delete @_onServerDoc

    create: ->
      return if @serverDoc
      return @pending.set pending | CREATE_LATER if (pending = @pending.value) & NOW
      @pending.set pending | CREATE_NOW

      @clientDoc['_v'] ||= 1
      clientDoc = clone @clientDoc
      sock.emit 'create', @coll, OJSON.toOJSON(clientDoc), (code, msg) =>
        Cascade.Block => @handleCreate code, clientDoc, msg

    handleCreate: (code, doc, msg) ->
      @pending.set @pending.value & ~CREATE_NOW

      if code is 'r'
        @reject.set msg || 'rejected'
      else
        @reject.set ''
        @serverDoc = doc

      @_notifyServerDoc() if @_onServerDoc
      @_loop()
      return

    read: (bulk) ->
      return if @conflict.value
      return @pending.set pending | READ_LATER if (pending = @pending.value) & NOW
      @pending.set pending | READ_NOW

      clientDoc = clone @clientDoc

      unless bulk
        sock.emit 'read', @coll, @id, (clientDoc && clientDoc['_v']), null, null, null, (code, arg) =>
          Cascade.Block => @handleRead code, arg, clientDoc
      true

    handleRead: (code, arg, clientDoc) ->
      @pending.set @pending.value & ~READ_NOW

      if code is 'r'
        @serverDelete()
        @reject.set arg || 'rejected'
      else
        @reject.set ''
        @serverCreate if code is 'd' then OJSON.fromOJSON(arg) else clientDoc

      @_notifyServerDoc() if @_onServerDoc
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
      if @_outlets
        Cascade.Block =>
          patchOutlets @_outlets, ops, @clientDoc, @_patchRegistry
      return

    'reset': ->
      @reject.set ''
      @conflict.set false
      @outbound = []
      @patchClient diff @clientDoc, @serverDoc
      return

    # never called if conflicted
    update: (ops) ->
      pending = @pending.value
      unless @serverDoc
        return @create unless pending & (CREATE | READ)

      @outgoing.push ops... if ops
      return @pending.set pending | UPDATE_LATER if pending & NOW

      @pending.set pending | UPDATE_NOW
      @_update()
      return

    _update: ->
      outgoing = @outgoing
      @outgoing = []
      unless outgoing[0]
        @pending.set @pending.value & ~UPDATE_NOW
        @_loop()
        return

      sock.emit 'update', @coll, @id, @serverDoc['_v'], OJSON.toOJSON(outgoing), (code, arg1, arg2, outgoing) =>
        Cascade.Block => @handleUpdate code, arg1, arg2, outgoing
      return

    handleUpdate: (code, arg1, arg2, outgoing) ->
      if code is 'r'
        @reject.set arg1 || 'rejected'
        if @outgoing.length
          outgoing.push @outgoing...
          @outgoing = outgoing
          @_update()
        else
          @pending.set @pending.value & ~UPDATE_NOW
          @_loop()
      else if code is 'c'
        if @serverDoc['_v'] > @clientDoc['_v']
          @_conflict()
        else
          outgoing.push @outgoing...
          @outgoing = outgoing
          @pending.set @pending.value & ~UPDATE_NOW
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
      return if @pending.value or @conflict.value
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
      @pending.set 0
      return

    'resolveConflict': ->
      return unless @serverDoc['_v'] > @clientDoc['_v']
      @conflict.set false
      @clientDoc['_v'] = @serverDoc['_v']
      @update diff @serverDoc, @clientDoc
      return

    'delete': ->
      return @pending.set pending | DELETE_LATER if (pending = @pending.value) & NOW
      @pending.set pending | DELETE_NOW

      unless @serverDoc
        @serverDelete()
      else
        sock.emit 'delete', @coll, @id, (code, msg) => Cascade.Block => @handleDelete code, msg
      return

    handleDelete: (code, msg) ->
      if code is 'r'
        @reject.set msg || 'rejected'
        @_loop()
      else
        @serverDelete()
      return

    serverDelete: ->
      delete @serverDoc
      @pending.set @pending.value & NOW
      @['reset']()
      return

    'run': (name, args, cb) ->
      return if @conflict.value or !@serverDoc
      @runQueue [name, args, cb] if name
      return @pending.set pending | RUN_LATER if (pending = @pending.value) & NOW
      @pending.set pending | RUN_NOW
      @_run()

    _run: ->
      unless arr = @runQueue()
        @pending.set @pending.value & ~RUN_NOW
        @_loop()
        return

      [cmd, args, cb] = arr

      sock.emit 'run', @coll, @id, @serverDoc['_v'], cmd, OJSON.toOJSON(args), (code) =>
        cb.apply null, arguments[1..] if code is 'o'
        @_run()
        return
      return

    _loop: ->
      pending = @pending.value

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
      @_clientUpdater ||= new Outlet (=> @update @_clientOps?.splice(0)), silent: true
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
          model = mvc.Model[d.namespace].read d.oid
          return model.get path[(i+1)..].concat(key).join('.')
        o = o[p] ||= {}

      o = o[key] ||= {}
      d = d[key]

      unless o['_']
        if d instanceof DBRef
          d = mvc.Model[d.namespace].read d.oid
        else
          d = clone d

        outlet = o['_'] = new Outlet d, silent: true
        path = path.concat key

        (@_pushers ||= []).push pusher = new Outlet (=>
          if !@conflict.value and ops = diff(@clientDoc, outlet.value, path: path)
            @clientDoc = diff.patch @clientDoc, ops

            # update descendant outlets whose value may have changed because of this change
            # patchOutlets @_outlets, ops, @clientDoc

            @_clientOps.push ops...
            pusher.modified()
          return
        ), silent: true

        outlet.outflows.add pusher
        pusher.outflows.add @_clientUpdater

      o['_']

    toString: -> "Model[#{@coll}][#{@id}][#{@clientDoc?['_v']}]"

  for _type,_config of configs.configs

    mvc.Model[_type] = class Model extends mvc.Model
      type = _type
      config = _config

      @name = 'Model'
      coll: type
      models = @models = {}

      @_applyStatic config
      @_applyMethods config

      # everything is optional
      @['create'] = @create = (idOrSpec, spec, cb) ->
        unless typeof idOrSpec is 'string' or idOrSpec instanceof ObjectID
          spec = idOrSpec
          idOrSpec = new ObjectID

        if typeof spec is 'function'
          cb = spec
          spec = undefined

        (model = models[idOrSpec] = new this idOrSpec, spec).create() unless model = models[idOrSpec]
        model.onServerDoc cb if cb
        model

      # cb is optional
      # can also call with an array of ids, optional array of versions and optional callback
      @['read'] = @read = (idOrSpec, cb) ->
        if typeof idOrSpec is 'string' or idOrSpec instanceof ObjectID
          (model = models[idOrSpec] = new this idOrSpec).read() unless model = models[idOrSpec]
          model.onServerDoc cb if cb
          return model
          
        else if Array.isArray idOrSpec
          if Array.isArray cb
            versions = cb
            cb = arguments[2]
          else
            versions = []

          sock.emit 'read', type, idOrSpec, versions, null, null, null, (code) =>
            if typeof code is 'object'
              Cascade.Block =>
                for id, arr of code
                  (model = models[id] ||= new this id).handleRead.apply model, arr

            cb() if cb

        else
          query = new @Query idOrSpec
          for id, model of models when query.exec model
            model.onServerDoc cb if cb
            return model

          return null unless cb

          sock.emit 'read', type, null, null, OJSON.toOJSON(idOrSpec), null, null, (code, arg) =>
            if code is 'd'
              doc = OJSON.fromOJSON arg
              cb models[doc['_id']] ||= new this doc['_id'], doc
            else
              cb null
            return

      @Query = (spec, sort, limit) -> new Query mvc.Model[type], spec, sort, limit

      constructor: (id, doc) ->
        # this is for patching the serverDoc with DBRefs instead of models. clone calls it
        return new DBRef type, id.id if id instanceof @constructor

        return model if model = models[id]
        models[id] = this

        super id, doc || {}

        prev = @Outlet.auto; @Outlet.auto = null
        debugMvc "Building #{@}"

        Cascade.Block =>
          @_applyConstructors config

        debugMvc "done building #{@}"
        @Outlet.auto = prev

module.exports.add = (type,config) -> configs.add type,config
module.exports.finish = -> configs.applyMixins()
