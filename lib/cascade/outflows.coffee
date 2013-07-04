makeId = require '../utils/id'
debug = global.debug 'ace:cascade:outflows'

class Outflows
  constructor: (@cascade) ->
    # uses an array for faster iteration
    # uses itself as a dictionary for uniqueness
    # addition is O(1), iteration is fast, deletion is O(n), but searches
    # from the end so repeated add/delete is likely to be fast
    @array = []

  add: (outflow) ->
    if (current = @[outflow.cid])?
      @[outflow.cid] = current + 1

    else
      @[outflow.cid ?= makeId()] = 1

      debug "adding outflow #{outflow} to #{@cascade}"

      @array.push(outflow)
      outflow.inflows?[@cascade.cid] = @cascade
      outflow.setPending? true if @cascade.pending

    return

  setPending: (tf) ->
    outflow.setPending? tf for outflow in @array
    return

  remove: (outflow) ->
    return unless (current = @[outflow.cid])?

    unless @[outflow.cid] = current - 1
      debug "removing outflow #{outflow} from #{@cascade}"

      delete @[outflow.cid]

      `for (var i = this.array.length; i >= 0; --i) {
        if (this.array[i] === outflow) {
          this.array.splice(i,1);
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

module.exports = Outflows
