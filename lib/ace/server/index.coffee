Ace = require '../index'
Router = require '../../routes/router'
Routing = require '../routing'
ExpressApp = require('express').application
{extend} = require '../mixin'

fs = require 'fs'

directories = (path) ->
  dir for dir in fs.readdirSync path when fs.statSync(dir).isDirectory()

# express sets route, parent
class App extends ExpressApp
  constructor: (settings) ->
    extend @settings, settings
    @on 'mount', (app) => @_configure()

  _configure: ->
    @_routeConfig = require(@settings['routes'])
    @_routes = Routing.buildRoutes @_routeConfig

    for name in directories('../../') when fs.existsSync path="./#{name}/server"
      fn(this, @_routeConfig[name]) if typeof (fn = require(path)) is 'function'


  handle: (req, res, next) ->
    ace = new Ace
    ace.routing.enable @_routeConfig, @_routes


module.exports = Ace

