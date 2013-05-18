Ace = require '../index'
Router = require '../../routes/router'
Routing = require '../routing'
ExpressApp = require('express').application
Template = require '../../mvc/template'
loadMVC = require './load_mvc'
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

    # load everything in server directories
    for name in directories('../../') when fs.existsSync path="./#{name}/server"
      fn(this, @_routeConfig[name]) if typeof (fn = require(path)) is 'function'

    # add controllers, views, templates
    loadMVC(@settings.mvc)

  handle: (req, res, next) ->
    ace = new Ace
    ace.routing.enable @_routeConfig, @_routes

    layout = new Template['layout']
    ace.appendTo(layout.$container)

    res.end layout.$root.toString()


module.exports = Ace

