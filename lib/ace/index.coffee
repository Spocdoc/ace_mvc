module.exports = class Ace
  acePath: ''

  constructor: ->
    @vars = {}
    @_build.apply this, arguments

require './link'
require('./build')(Ace)
