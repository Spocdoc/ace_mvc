Outlet = require '../cascade/outlet'

class Variable extends Outlet
  constructor: (@path, fn, historyOutlets) ->

    super fn

    historyOutlets.on 'didNavigate', =>
      @set(historyOutlets.to.get(path).get())

    historyOutlets.on 'newOutlet', (path, key, outlet) ->
      return unless @_samePath path, key
      outlet.outflows.add => @set(outlet.get())

    @outflows.add =>
      historyOutlets.get(path).set(@_value)

  _samePath: (path, key) ->
    thisLen = @path.length
    return false if path.length != thisLen-1
    return false if key != @path[thisLen-1]
    for v,i in path
      return false unless v == @path[i]
    return true

module.exports = Variable
