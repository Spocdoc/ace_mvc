fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'

directories = (path) ->
  dir for dir in fs.readdirSync path when fs.statSync("#{path}/#{dir}").isDirectory()

# express sets route, parent
class App
  constructor: (settings) ->
    # TODO: is this really the only way to extend express. wtf
    extend @, express()
    delete @handle

    extend @settings, settings
    @on 'mount', (app) => @_configure()

  _configure: ->
    # load everything in server directories
    basePath = path.resolve(__dirname, '../../')
    for name in directories(basePath) when fs.existsSync(path="#{basePath}/#{name}/server") and name isnt 'ace'
      fn(this, @settings[name]) if typeof (fn = require(path)) is 'function'

    # add controllers, views, templates
    require('./load_mvc')(@settings.mvc)

    Routing = require '../routing'
    @_routeConfig = require(@settings['routes'])
    @_routes = Routing.buildRoutes @_routeConfig

  handle: (req, res, next) ->
    Ace = require '../index'
    Template = require '../../mvc/template'

    ace = new Ace
    ace.routing.enable @_routeConfig, @_routes

    html = """
<html>
    <head>
        <title></title>
    </head>
</html>
    """

    $html = $(html)
    ace.rootType.set('body')

    ace.routing.router.route req.url
    ace.appendTo($html)

    res.end "<!DOCTYPE html>#{$html.toString()}"


module.exports = App

