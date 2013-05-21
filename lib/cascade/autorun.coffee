Outlet = require './outlet'

class Autorun extends Outlet
  autoruns = []

  constructor: (func) ->
    if this instanceof Autorun
      super
      @_autorunFunc = func
    else
      autoruns.push new Autorun(func)

  detach: ->
    ret = super
    @set @_autorunFunc, silent: true
    ret


module.exports = Autorun
