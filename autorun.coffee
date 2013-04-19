Outlet = require './outlet'

class Autorun extends Outlet
  autoruns = []

  constructor: (func) ->
    if this instanceof Autorun
      super
    else
      autoruns.push(new Autorun(func))

  detach: ->
    # retain indirect reference -- the func -- so Autorun can be manually run() again
    indirect = @indirect
    ret = super
    @indirect = indirect
    return ret


module.exports = Autorun
