Emitter = require '../events/emitter'
{include, extend} = require '../mixin'

class Cascade
  count = 0

  uniqueId = ->
    "#{++count}-Cascade"

  include Cascade, Emitter

  constructor: (@func) ->
    @func ||= ->
    @inflows = {}
    @outflows = new Outflows(this)
    @pending = new Pending(this)
    @cid = uniqueId()

  class Outflows
    include Outflows, Emitter

    constructor: (@cascade) ->
      # uses an array for faster iteration
      # uses itself as a dictionary for uniqueness
      # addition is O(1), iteration is fast, deletion is O(n), but searches
      # from the end so repeated add/delete is likely to be fast
     @_arr = []

    add: (outflow) ->
      return if @[outflow.cid]?
      @[outflow.cid ?= uniqueId()] = 1
      @_arr.push(outflow)
      outflow.inflows?[@cascade.cid] = @cascade
      return

    remove: (outflow) ->
      delete @[outflow.cid]
      `for (var i = this._arr.length; i >= 0; --i) {
        if (this._arr[i] === outflow) {
          this._arr.splice(i,1);
          break;
        }
      }`
      delete outflow.inflows?[@cascade.cid]
      return

    # removes all the outflows (and removes this cascade from the inflows of
    # each). These can be restored with #attach
    # @returns array of outflows
    detach: ->
      ret = @_arr
      @_arr = []
      for outflow in ret
        delete outflow.inflows?[@cascade.cid]
        delete @[outflow.cid]
      return ret

    # @param arr [Array] array of outflows to (re)attach
    attach: (arr) ->
      @add outflow for outflow in arr
      @_run arr

    _calculate: (dry=false, arr=@_arr) ->
      for outflow in arr
        if typeof outflow._calculate == 'function'
          outflow._calculate(dry)
        else if not dry
          outflow()
      return

    _run: (arr=@_arr) ->
      @_setPending arr
      if Cascade.roots
        Cascade.roots.push outflow for outflow in arr
      else
        @_calculate(false, arr)
      return

    _setPending: (arr=@_arr) ->
      outflow.pending?.set?(true) for outflow in arr
      return

  class Pending
    constructor: (@cascade) ->
      @_pending = false
    get: -> @_pending
    set: (pending) ->
      return if pending and @cascade.calculating
      return if !!pending == @_pending
      @_pending = !!pending
      if @_pending
        @cascade.outflows._setPending()
      return

  # remove all the inflows
  detach: ->
    inflows = @inflows
    inflow.outflows.remove this for cid,inflow of inflows
    return
    
  run: ->
    @pending.set(true)
    if Cascade.roots
      Cascade.roots.push(this)
    else
      @_calculate(false)
    return

  cascade: ->
    @calculating = true
    @outflows._run()
    @calculating = false

  _calculateDone: (dry) ->
    @calculating = true
    if @_stopPropagation
      delete @_stopPropagation
      dry = true

    @pending.set(false)
    @outflows._calculate(dry)
    @pending.set(false)
    @calculating = false

  _calculate: (dry) ->
    return unless @pending.get()
    return if @calculating

    for cid,inflow of @inflows when inflow.pending.get()
      if not @outflows[inflow.cid]?
        @_noDry = true if not dry # ie, calculate this anyway if another input is dry because at least 1 input is "wet"
        return

    @calculating = true
    @_calculateNum = (@_calculateNum || 0) + 1

    if @_noDry
      delete @_noDry
      dry = false

    if not @func.length
      @func() if not dry
      @_calculateDone(dry)
    else if dry
      @_calculateDone(dry)
    else
      num = @_calculateNum
      @func =>
        return if num != @_calculateNum
        @_calculateDone(dry)

    @calculating = false
    return

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

      if roots.post
        for root in roots.post
          if root instanceof Cascade
            root._calculate(false)
          else if typeof root is 'function'
            root()

    ret

  unblockRunner = (func) ->
    roots = Cascade.roots
    delete Cascade.roots
    ret = func()
    Cascade.roots = roots
    ret

  postblockRunner = (func) ->
    if roots = Cascade.roots
      (roots.post ||= []).push func
    else
      func()
    return

  @Block: (func) ->
    if this instanceof Cascade.Block
      -> blockRunner(func)
    else
      blockRunner(func)

  # runs the function outside of the current block if there is one, then puts
  # the original block back
  @Unblock: (func) ->
    if this instanceof Cascade.Unblock
      -> unblockRunner(func)
    else
      unblockRunner(func)

  # runs the function after the current block if there is one
  @Postblock: (func) ->
    if this instanceof Cascade.Postblock
      -> postblockRunner(func)
    else
      postblockRunner(func)


module.exports = Cascade
