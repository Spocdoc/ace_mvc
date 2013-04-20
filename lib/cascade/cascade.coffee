class Cascade
  count = 0

  uniqueId = ->
    "Cascade-#{++count}"

  constructor: (@func) ->
    @func ||= ->
    @inflows = {}
    @outflows = new Outflow(this)
    @pending = new Pending(this)
    @cid = uniqueId()

  class Outflow
    constructor: (@cascade) ->

    add: (outflow) ->
      outflow.cid ?= uniqueId()
      return if @[outflow.cid]?
      @[outflow.cid] = outflow
      outflow.inflows?[@cascade.cid] = @cascade
      return

    remove: (outflow) ->
      delete @[outflow.cid]
      delete outflow.inflows?[@cascade.cid]
      return

    _calculate: (dry) ->
      for cid, outflow of @ when @hasOwnProperty(cid) and cid != 'cascade'
        if typeof outflow._calculate == 'function'
          outflow._calculate(dry)
        else if not dry
          outflow()
      return

    _run: ->
      @_setPending()
      if Cascade.roots
        for cid, outflow of @ when @hasOwnProperty(cid) and cid != 'cascade'
          Cascade.roots.push outflow
      else
        @_calculate(false)

    _setPending: ->
      for cid, outflow of @ when @hasOwnProperty(cid) and cid != 'cascade'
        outflow.pending?.set?(true)
      return

  class Pending
    constructor: (@cascade) ->
      @_pending = false
    get: -> @_pending
    set: (pending) ->
      return if !!pending == @_pending
      @_pending = !!pending
      @cascade.outflows._setPending() if @_pending

  # remove all the inflows
  detach: ->
    inflows = @inflows
    inflow.outflows.remove this for cid,inflow of inflows
    
  run: ->
    @pending.set(true)
    if Cascade.roots
      Cascade.roots.push(this)
    else
      @_calculate(false)
    return

  cascade: ->
    @outflows._run()

  _calculate: (dry) ->
    return if not @pending.get()
    (return if not @outflows[inflow.cid]?) for cid,inflow of @inflows when inflow.pending.get()

    @func() if not dry

    if @_stopPropagation?
      delete @_stopPropagation
      dry = true

    @pending.set(false)
    @outflows._calculate(dry)

  # can be called by the func to prevent updating outflows
  stopPropagation: ->
    @_stopPropagation = true

  blockRunner = (func) ->
    if Cascade.roots
      ret = func()
    else
      Cascade.roots = []
      ret = func()
      roots = Cascade.roots
      delete Cascade.roots
      for root in roots
        if root instanceof Cascade
          root._calculate(false)
        else if typeof root is 'function'
          root()
    return ret

  @Block: (func) ->
    if this instanceof Cascade.Block
      return -> blockRunner(func)
    else
      return blockRunner(func)

module.exports = Cascade
