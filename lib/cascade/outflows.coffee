Emitter = require '../events/emitter'
{include, extend} = require '../mixin'

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
    @[outflow.cid ?= @cascade.constructor.id()] = 1
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
        outflow._calculate(dry, @cascade)
      else if not dry
        outflow()
    return

  _run: (arr=@_arr) ->
    @_setPending arr
    if @cascade.constructor.roots
      @cascade.constructor.roots.push => @_calculate(false, arr)
    else
      @_calculate(false, arr)
    return

  _setPending: (arr=@_arr) ->
    outflow.pending?.set?(true) for outflow in arr
    return

module.exports = Outflows
