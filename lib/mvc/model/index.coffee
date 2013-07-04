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

module.exports = (pkg) ->

  OJSON = pkg.ojson || require('../../utils/ojson')(pkg)
  cascade = pkg.cascade || require('../../cascade')(pkg)
  mvc = pkg.mvc

  patchOutlets = diff.toOutlets
  Cascade = cascade.Cascade
  Outlet = cascade.Outlet

  mvc.sock = sock = global.io.connect '/'

  sock.on 'create', (data) ->
    doc = OJSON.fromOJSON data['v']
    mvc.Model[data['c']].read(doc['_id']).serverCreate doc
    return

  sock.on 'update', (data) ->
    mvc.Model[data['c']].read(data['i']).serverUpdate data['e'], OJSON.fromOJSON data['d']
    return

  sock.on 'delete', (data) ->
    mvc.Model[data['c']].read(data['i']).serverDelete()
    return

  Query = require('./query')(pkg)

  mvc.Global.prototype['Model'] = mvc.Model = class Model extends mvc.Global
    @name = 'Model'

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

    constructor: (id, @clientDoc) ->
      try
        id = new ObjectID id unless id instanceof ObjectID
      catch _error

      @id = id

      @clientDoc['_id'] ||= @id
      @clientDoc['_v'] ||= 0

      @serverDoc = clone @clientDoc if @clientDoc['_v'] > 0

      @outgoing = [] # outgoing ops when pending
      @incoming = [] # incoming ops when pending

      @runQueue = queue()

      # status is one of
      #   ''
      #   'rejected'
      #   'conflicted'
      #   'deleted'
      @['pending'] = @pending = new Outlet 0
      @['status'] = @status = new Outlet
      @['error'] = @error = new Outlet

    @fromJSON: (obj) ->
      (model = new mvc.Model[obj[0]] obj[1], obj[2]).read()
      model
    toJSON: -> [@coll, OJSON.toOJSON @id, OJSON.toOJSON @serverDoc]
    OJSON.register 'Model': this
    @allModels: ->
      models = []
      i = 0
      for type of configs.configs
        for id, model of mvc.Model[type].models
          models[i++] = model
      models

    onServerDoc: (cb) ->
      return cb this if @serverDoc
      (@_onServerDoc ||= []).push cb

    _notifyServerDoc: ->
      cb this for cb in @_onServerDoc
      delete @_onServerDoc

    create: ->
      return @pending.set pending | CREATE_LATER if (pending = @pending.value) & NOW
      @pending.set pending | CREATE_NOW

      @clientDoc['_v'] ||= 1

      serverDoc = @serverDoc || clone @clientDoc

      sock.emit 'create', {'c': @coll, 'v': OJSON.toOJSON serverDoc}, (reply) =>
        @pending.set @pending.value & ~CREATE_NOW
        @serverDoc = serverDoc

        switch reply?[0]
          when 'rej'
            delete @serverDoc
            @_reject reply[1]
          when 'up'
            @serverUpdate reply[1], OJSON.fromOJSON reply[2]
          when 'doc'
            @serverCreate OJSON.fromOJSON reply[1]

        @_notifyServerDoc() if @_onServerDoc

        @_doPending()

    read: ->
      return @pending.set pending | READ_LATER if (pending = @pending.value) & NOW
      @pending.set pending | READ_NOW

      serverDoc = @serverDoc || clone @clientDoc

      sock.emit 'read', {'c': @coll, 'i': @id, 'e': serverDoc['_v']}, (reply) =>

        @pending.set @pending.value & ~READ_NOW
        @serverDoc = serverDoc

        switch reply?[0]
          when 'doc'
            @serverCreate OJSON.fromOJSON reply[1]
          when 'no'
            delete @serverDoc
            @serverDelete()
          when 'rej'
            delete @serverDoc
            @_reject reply[1]
            @serverDelete()

        @_notifyServerDoc() if @_onServerDoc

        @_doPending()

    update: (ops) ->
      @outgoing.push ops... if ops
      return if @conflicted or @rejected?
      return @pending.set pending | UPDATE_LATER if (pending = @pending.value) & NOW
      @pending.set pending | UPDATE_NOW
      @_doUpdate()

    'delete': ->
      return @pending.set pending | DELETE_LATER if (pending = @pending.value) & NOW
      @pending.set pending | DELETE_NOW

      unless @serverDoc
        @serverDelete()
      else
        sock.emit 'delete', {'c': @coll, 'i': @id}, (reply) =>
          if reply
            @_doPending()
          else
            @serverDelete()

    'run': (name, args, cb) ->
      @runQueue [name, args, cb] if name
      return if @conflicted or @rejected? or (pending = @pending.value) & NOW
      @pending.set pending | RUN_NOW
      @_doRun()

    'resolveConflict': ->
      Cascade.Block =>
        @error.set ''
        @status.set ''
        delete @conflicted
      @update()
      return

    'resolveReject': ->
      Cascade.Block =>
        @error.set ''
        @status.set ''
        delete @rejected
      if @incoming[@serverDoc['_v']]
        @_conflict()
      else if @serverDoc['_v']
        @update()
      else
        @create()
      return

    serverCreate: (doc) ->
      return unless doc['_v'] > @serverDoc['_v']
      --doc['_v']

      incoming = []
      incoming[@serverDoc['_v']] = [{'o': 1, 'v': doc}]
      incoming[k] = @incoming[v] for k of @incoming when k > doc['_v']
      @incoming = incoming
      @_doServerUpdate()
      return

    serverUpdate: (version, ops) ->
      return if version < @serverDoc['_v']
      @incoming[version] = ops
      @_doServerUpdate()

    serverDelete: ->
      Cascade.Block =>
        @status.set 'deleted'
        @error.set ''
        delete @constructor.models[@id]
        delete @serverDoc
        @pending.set 0
      return

    get: (key) ->
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
          model = new mvc.Model[d.namespace] d.oid
          return model.get path[(i+1)..].concat(key).join('.')
        o = o[p] ||= {}

      o = o[key] ||= {}
      d = d[key]

      unless o['_']
        if d instanceof DBRef
          d = new mvc.Model[d.namespace] d.oid
        else
          d = clone d

        outlet = o['_'] = new Outlet d, silent: true
        path = path.concat key

        (@_pushers ||= []).push pusher = new Outlet (=>
          if ops = diff(@clientDoc, outlet._value, path: path)
            @clientDoc = diff.patch @clientDoc, ops

            # update descendant outlets whose value may have changed because of this change
            # patchOutlets @_outlets, ops, @clientDoc

            @_clientOps.push ops...
            pusher.modified()
        ), silent: true

        outlet.outflows.add pusher
        pusher.outflows.add @_clientUpdater

      o['_']

    toString: -> "Model[#{@coll}][#{@id}][#{@clientDoc['_v']}]"

    _doPending: ->
      pending = @pending.value

      if pending & DELETE_LATER
        @delete()
      else if pending & CREATE_LATER
        @create()
      else if pending & READ_LATER
        @read()
      else unless @conflicted or @rejected?
        if pending & RUN_LATER
          @run()
        else if pending & UPDATE_LATER
          @update()
        else
          @_doServerUpdate()
      return

    _doUpdate: ->
      outgoing = @outgoing
      @outgoing = []
      unless outgoing[0]
        @pending.set @pending.value & ~UPDATE_NOW
        @_doPending()
        return

      version = @serverDoc['_v']

      sock.emit 'update', {'c': @coll, 'i': @id, 'e': @serverDoc['_v'], 'd': OJSON.toOJSON outgoing}, (err) =>
        if err && err[0] is 'up'
          ++@serverDoc['_v']
          diff.patch(@serverDoc, outgoing)
          @serverUpdate err[1], OJSON.fromOJSON err[2]
          @_doUpdate()

        else if err
          outgoing.push @outgoing...
          @outgoing = outgoing
          @pending.set pending.value & ~UPDATE_NOW
          switch err[0]
            when 'ver' then @_conflict err[1] # this version too old. will get updates (or may have queued already)
            when 'rej' then @_reject err[1] # if updates applied, leads to invalid doc.
            when 'no' then @serverDelete()
          @_doPending()
        else
          ++@serverDoc['_v']
          diff.patch(@serverDoc, outgoing)
          @_doUpdate()
      return

    _doRun: ->
      unless arr = @runQueue()
        @pending.set @pending.value & ~RUN_NOW
        @_doPending()
        return

      [cmd, args, cb] = arr

      sock.emit 'run', {'c': @coll, 'i': @id, 'e': @serverDoc['_v'], 'm': cmd, 'a': OJSON.toOJSON args}, (err) =>
        cb.apply null, arguments
        @_doRun()
        return
      return

    _reject: (data) ->
      @rejected = data ?= ''

      Cascade.Block =>
        @status.set 'rejected'
        @error.set @rejected
      return

    _conflict: (data) ->
      @conflicted ||= data || true
      return if @rejected?

      if @incoming[@serverDoc['_v']]
        @_patchIncoming()
        Cascade.Block =>
          @status.set 'conflicted'
          @error.set ''

      return

    _doServerUpdate: ->
      return if @rejected? or @pending.value

      if @conflicted
        @_conflict()
      else
        if (ops = @_patchIncoming()).length
          @clientDoc = diff.patch @clientDoc, ops
          Cascade.Block =>
            patchOutlets @_outlets, ops, @clientDoc, @_patchRegistry

    _patchIncoming: ->
      a = []
      while ops = @incoming[@serverDoc['_v']]
        a.push ops...
        delete @incoming[@serverDoc['_v']]
        @serverDoc = diff.patch @serverDoc, ops
        ++@serverDoc['_v']
      return a

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
        if typeof spec is 'function'
          spec = undefined
          cb = spec

        unless typeof idOrSpec is 'string' or idOrSpec instanceof ObjectID
          spec = idOrSpec
          idOrSpec = new ObjectID

        (model = models[idOrSpec] = new this idOrSpec, spec).create() unless model = models[idOrSpec]
        model.onServerDoc cb if cb
        model

      # cb is optional
      @['read'] = @read = (idOrSpec, cb) ->
        if typeof idOrSpec is 'string' or idOrSpec instanceof ObjectID
          (model = models[idOrSpec] = new this idOrSpec).read() unless model = models[idOrSpec]
          model.onServerDoc cb if cb
          return model
          
        else
          query = new @Query idOrSpec
          for id, model of models when query.exec model
            model.onServerDoc cb if cb
            return model

          return null unless cb

          sock.emit 'read', {'c': type, 'q': OJSON.toOJSON idOrSpec}, (reply) =>
            switch reply?[0]
              when 'no' then return cb null
              when 'doc'
                doc = reply[1]
                return cb models[doc['_id']] ||= new this doc['_id'], doc

            cb null

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
