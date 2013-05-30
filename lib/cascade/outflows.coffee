{include, extend} = require '../mixin'
makeId = require '../id'

class Outflows extends Array
  constructor: (@cascade) ->
    # uses an array for faster iteration
    # uses itself as a dictionary for uniqueness
    # addition is O(1), iteration is fast, deletion is O(n), but searches
    # from the end so repeated add/delete is likely to be fast

  add: (outflow) ->
    if (current = @[outflow.cid])?
      @[outflow.cid] = current + 1

    else
      @[outflow.cid ?= makeId()] = 1

      @push(outflow)
      outflow.inflows?[@cascade.cid] = @cascade
      outflow.setPending? true if @cascade.pending

    return

  setPending: (tf) ->
    outflow.setPending? tf for outflow in this
    return

  remove: (outflow) ->
    return unless (current = @[outflow.cid])?

    unless @[outflow.cid] = current - 1
      delete @[outflow.cid]

      `for (var i = this.length; i >= 0; --i) {
        if (this[i] === outflow) {
          this.splice(i,1);
          break;
        }
      }`

      delete outflow.inflows?[@cascade.cid]
      outflow.setPending? false unless outflow.running

    return

  removeAll: (outflow) ->
    return unless @[outflow.cid]?
    @[outflow.cid] = 1
    @remove outflow
    return

  # removes all the outflows (and removes this cascade from the inflows of
  # each). These can be restored with #attach
  detach: ->
    ret = @splice(0)
    for outflow in ret
      delete outflow.inflows?[@cascade.cid]
      delete @[outflow.cid]
    return ret

  attach: (arr) ->
    @add outflow for outflow in arr
    return

module.exports = Outflows
