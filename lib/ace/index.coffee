module.exports = class Ace
  acePath: ''

  constructor: ->
    @vars = {}
    if arguments.length is 1 and Array.isArray arguments[0]
      @_build.apply this, arguments[0]
    else
      @_build.apply this, arguments

require './link'
require './outlet_wrap'
require './jquery_monkey'
require('./build')(Ace)
