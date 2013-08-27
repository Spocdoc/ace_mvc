module.exports = class Ace
  acePath: ''

  constructor: ->
    @aceComponents = {}
    @vars = {}

require './link'
module.require './server', 'server'
module.require './client', 'client'

