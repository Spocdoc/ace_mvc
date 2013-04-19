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

    add: (outflows...) ->
      for outflow in outflows
        outflow.cid ?= uniqueId()
        return if @[outflow.cid]?
        @[outflow.cid] = outflow
        outflow.inflows?[@cascade.cid] = @cascade
      return

    remove: (outflow) ->
      delete @[outflow.cid]
      delete outflow.inflows?[@cascade.cid]
      return

    _run: ->
      for cid, outflow of @ when @hasOwnProperty(cid) and cid != 'cascade'
        if typeof outflow._calculate == 'function'
          outflow._calculate()
        else
          outflow()
      return

    _setPending: ->
      for cid, outflow of @ when @hasOwnProperty(cid) and cid != 'cascade'
        outflow.pending?.set?(true)
      return

  class Pending
    constructor: (@cascade) ->
      @_pending = false
    get: -> @_pending
    set: (pending) ->
      return if pending == @_pending
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
      @_calculate()
    return

  _calculate: ->
    return if not @pending.get()
    (return if not @outflows[inflow.cid]?) for cid,inflow of @inflows when inflow.pending.get()
    @func()
    @pending.set(false)
    @outflows._run()

  blockRunner = (func) ->
    if Cascade.roots
      ret = func()
    else
      Cascade.roots = []
      ret = func()
      roots = Cascade.roots
      delete Cascade.roots
      root._calculate() for root in roots
    return ret

  @Block: (func) ->
    if this instanceof Cascade.Block
      return -> blockRunner(func)
    else
      return blockRunner(func)

module.exports = Cascade
