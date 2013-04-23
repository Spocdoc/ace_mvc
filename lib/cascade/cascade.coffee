class Cascade
  count = 0

  uniqueId = ->
    "Cascade-#{++count}"

  constructor: (@func) ->
    @func ||= ->
    @inflows = {}
    @outflows = new Outflows(this)
    @pending = new Pending(this)
    @cid = uniqueId()

  class Outflows
    constructor: (@cascade) ->
      # uses an array for faster iteration
      # uses itself as a dictionary for uniqueness
      @arr = []

    add: (outflow) ->
      return if @[outflow.cid]?
      @[outflow.cid ?= uniqueId()] = @arr.push(outflow)-1
      outflow.inflows?[@cascade.cid] = @cascade
      return

    remove: (outflow) ->
      index = @[outflow.cid]
      delete @[outflow.cid]
      @arr.splice(index, 1) if index?
      delete outflow.inflows?[@cascade.cid]
      return

    # removes all the outflows (and removes this cascade from the inflows of
    # each). These can be restored with #attach
    # @returns array of outflows
    detach: ->
      ret = @arr
      @arr = []
      for outflow in ret
        delete outflow.inflows?[@cascade.cid]
        delete @[outflow.cid]
      return ret

    # @param arr [Array] array of outflows to (re)attach
    attach: (arr) ->
      @add outflow for outflow in arr
      @_run arr

    _calculate: (dry=false, arr=@arr) ->
      for outflow in arr
        if typeof outflow._calculate == 'function'
          outflow._calculate(dry)
        else if not dry
          outflow()
      return

    _run: (arr=@arr) ->
      @_setPending arr
      if Cascade.roots
        Cascade.roots.push outflow for outflow in arr
      else
        @_calculate(false, arr)

    _setPending: (arr=@arr) ->
      outflow.pending?.set?(true) for outflow in arr
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
