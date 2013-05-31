Outlet = require './outlet'

autos = []

class Auto extends Outlet
  @name = 'Auto'
  constructor: (init, options={}) ->
    options.auto = true
    unless this instanceof Auto
      autos.push new Auto init, options
      return
    super init, options

module.exports = Auto
