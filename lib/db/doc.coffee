`
// ==ClosureCompiler==
// @compilation_level ADVANCED_OPTIMIZATIONS
// @js_externs module.exports
// ==/ClosureCompiler==
`

Emitter = require '../events/emitter'
diff = require '../diff'

SUB_LATER   = 1 << 0
SUB_NOW     = 3 << 0
USUB_LATER  = 1 << 2
USUB_NOW    = 3 << 2
UP_LATER    = 1 << 4
UP_NOW      = 3 << 4
READ_LATER  = 1 << 6
READ_NOW    = 3 << 6
DEL_LATER   = 1 << 8
DEL_NOW     = 3 << 8
CREATE_LATER = 1 << 10
CREATE_NOW   = 3 << 10

class Doc
  constructor: (@coll, @id, @doc = {}) ->
    @db = @coll.db
    @doc._v ||= 0
    @outgoing = [] # outgoing ops when pending
    @incoming = [] # incoming ops when pending
    @refs = 0
    @pending = 0

  # these are for expiring old models in the collection
  ref: ->
    if ++@refs == 1
      @coll._ref(this)
    return
  unref: ->
    if --@refsoff == 0
      @coll._unref(this)
    return

  on: (event) ->
    Emitter.on.apply(this, arguments)
    @_subscribe() if event is 'update'
    this

  off: ->
    Emitter.off.apply(this, arguments)
    @_unsubscribe() if !@_emitter?['update']
    this

  create: ->
    if @pending & ~CREATE_NOW
      @pending |= CREATE_LATER
      return
    @pending |= CREATE_NOW
    @doc._v ||= 1
    @db.create this, (err) =>
      @pending &= ~CREATE_NOW
      if err
        @_reject err[1]
      @_doPending()
    return

  read: ->
    return if @live
    if @pending & ~READ_NOW
      @pending |= READ_LATER
      return
    @pending |= READ_NOW

    @db.read this, (err) =>
      @pending &= ~READ_NOW
      @_handleRead(err)
      @_doPending()

  update: (ops) ->
    @outgoing.push ops if ops
    return if @conflicted or @rejected?
    if @pending & ~UP_NOW
      @pending |= UP_LATER
      return
    @pending |= UP_NOW
    @_doUpdate()

  delete: ->
    if @pending & ~DEL_NOW
      @pending |= DEL_LATER
      return
    @pending |= DEL_NOW
    @db.delete this, (err) =>
      if err
        @emit 'undelete', err[1]
      else
        @serverDelete()
    return

  # resolve conflicted state
  resolveConflict: (version) ->
    return unless version == @doc._v
    delete @conflicted
    @update()
    return

  # resolve rejected state
  resolveReject: ->
    delete @rejected
    if @incoming[@doc._v]
      @_conflict()
    else if @doc._v
      @update()
    else
      @create()
    return

  serverCreate: (doc) ->
    return unless doc._v > @doc._v
    --doc._v

    incoming = []
    incoming[@doc._v] = [{'o': 1, 'v': doc}]

    for k of @incoming when k > doc._v
      incoming[k] = @incoming[v]

    @incoming = incoming
    @_doServerUpdate()
    return

  serverUpdate: (version, ops) ->
    return if version < @doc._v
    @incoming[version] = ops
    @_doServerUpdate()

  serverDelete: ->
    @emit 'delete'
    @_delete()
    return

## private methods

  _subscribe: ->
    return if @live
    if @conflicted or @rejected?
      @pending |= SUB_LATER
      return
    if @pending
      if (@pending & USUB_NOW) is USUB_LATER
        @pending &= ~USUB_NOW
      else
        @pending |= SUB_LATER
      return
    @pending |= SUB_NOW
      
    @ref()
    @db.subscribe this, (err) =>
      @pending &= ~SUB_NOW
      @live = true
      @_handleRead(err)
      @_doPending()

  _unsubscribe: ->
    if @pending
      if (@pending & SUB_NOW) is SUB_LATER
        @pending &= ~SUB_NOW
      else
        @pending |= USUB_LATER
      return
    @pending |= USUB_NOW

    @unref()
    @db.unsubscribe this, =>
      @pending &= ~USUB_NOW
      @_doPending()

  _doPending: ->
    if @pending & CREATE_LATER
      @create()
    else if @pending & READ_LATER
      @read()
    else unless @conflicted or @rejected?
      if @pending & UP_LATER
        @update()
      else if @pending & SUB_LATER
        @_subscribe()
      else if @pending & USUB_LATER
        @_unsubscribe()
      else
        @_doServerUpdate()
    return

  emit: Emitter.emit

  _handleRead: (err) ->
    if err
      switch err[0]
        when 'doc'
          doc = err[1]
          @serverCreate doc
        when 'no'
          @live = false
          @serverDelete()
        when 'rej'
          @_reject err[1]
          @serverDelete()
    return

  _doUpdate: ->
    outgoing = @outgoing
    @outgoing = []
    unless outgoing[0]
      @pending &= ~UP_NOW
      @_doPending()
      return

    (flat = []).push(outgoing...)

    version = @doc._v

    @db.update this, flat, (err) =>
      if err
        outgoing.push.apply(outgoing, @outgoing)
        @outgoing = outgoing
        @pending &= ~UP_NOW
        switch err[0]
          when 'ver' then @_conflict err[1] # this version too old. will get updates (or may have queued already)
          when 'rej' then @_reject err[1] # if updates applied, leads to invalid doc.
          when 'no' then @serverDelete()
        @_doPending()
      else
        ++@doc._v
        diff.patch(@doc, ops) for ops in outgoing
        @_doUpdate()
    return

  _reject: (data) ->
    @rejected = data ?= ''
    @emit 'reject', data
    return

  _conflict: (data) ->
    @conflicted ||= data || true
    return if @rejected?
    return if !@incoming[@doc._v] and @live
    @_patchIncoming()
    [outgoing, @outgoing] = [@outgoing, []]
    @emit 'conflict', @doc._v, outgoing
    return

  _doServerUpdate: ->
    return if @pending || @rejected?

    if @conflicted
      @_conflict()
    else
      if (a = @_patchIncoming()).length
        @emit 'update', a

  _patchIncoming: ->
    a = []
    while ops = @incoming[@doc._v]
      a.push ops...
      delete @incoming[@doc._v]
      @doc = diff.patch @doc, ops
      ++@doc._v
    return a

  _delete: ->
    unless @_deleted
      @_deleted = true
      @coll.delete(@id)
      @on = => this
      @emit = ->
      @off = => this
      Emitter.off.apply(this, arguments)
      @pending = 0
      @live = false
    return

module.exports = Doc
