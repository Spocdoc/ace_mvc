Emitter = require '../events/emitter'
{include, extend} = require '../mixin'

class Outflows
  id = do ->
    count = 0
    ->
      count = if count+1 == count then 0 else count+1
      "#{count}-Cascade"

  include Outflows, Emitter

  constructor: (@cascade) ->
    # uses an array for faster iteration
    # uses itself as a dictionary for uniqueness
    # addition is O(1), iteration is fast, deletion is O(n), but searches
    # from the end so repeated add/delete is likely to be fast
   @_arr = []

  add: (outflow) ->
    if (current = @[outflow.cid])?
      @[outflow.cid] = current + 1

    else
      @[outflow.cid ?= id()] = 1

      @_arr.push(outflow)
      outflow.inflows?[@cascade.cid] = @cascade

    return

  remove: (outflow) ->
    return unless (current = @[outflow.cid])?

    unless @[outflow.cid] = current - 1
      delete @[outflow.cid]

      `for (var i = this._arr.length; i >= 0; --i) {
        if (this._arr[i] === outflow) {
          this._arr.splice(i,1);
          break;
        }
      }`

      delete outflow.inflows?[@cascade.cid]

    return

  removeAll: (outflow) ->
    return unless @[outflow.cid]?
    @[outflow.cid] = 1
    @remove outflow
    return

  # removes all the outflows (and removes this cascade from the inflows of
  # each). These can be restored with #attach
  detach: ->
    ret = @_arr
    @_arr = []
    for outflow in ret
      delete outflow.inflows?[@cascade.cid]
      delete @[outflow.cid]
    return ret

  attach: (arr) ->
    @add outflow for outflow in arr
    return

  _calculate: (dry, arr=@_arr) ->
    for outflow in arr
      if typeof outflow._calculate == 'function'
        outflow._calculate(dry, @cascade)
      else if not dry
        outflow()
    return

  _setPending: (arr=@_arr) ->
    outflow.pending?.set?(true) for outflow in arr
    return

module.exports = Outflows
