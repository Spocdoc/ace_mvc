fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
Url = require '../../url'
Bundler = require './bundler'

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
    for name in directories(basePath) when fs.existsSync(p="#{basePath}/#{name}/server") and name isnt 'ace'
      fn(this, @settings[name]) if typeof (fn = require(p)) is 'function'

    Template = require '../../mvc/template'
    View = require '../../mvc/view'
    Controller = require '../../mvc/controller'

    # add controllers, views, templates
    listMvc = require('../../mvc/server/list_mvc')
    mvc = listMvc(@settings.mvc.templates, @settings.mvc.files)
    Template.add name, dom for name, dom of mvc['template']
    View.add name, require p for name, p of mvc['view']
    Controller.add name, require p for name, p of mvc['controller']

    Routing = require '../routing'
    @_routeConfig = require(@settings['routes'])
    @_routes = Routing.buildRoutes @_routeConfig

    @bundler = new Bundler @settings['bundler'], @settings['mvc']

  handle: (req, res, next) ->
    return if @bundler.serveScript req, res

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

    # add client-side script
    @bundler.getUris (pathLocal, pathExtern, pathProd) =>
      if @settings['debug']
        $html.append $("<script type=\"text/javascript\" src=\"#{pathExtern}\"></script>")
        $html.append $("<script type=\"text/javascript\" src=\"#{pathLocal}\"></script>")
      else
        $html.append $("<script type=\"text/javascript\" src=\"#{pathProd}\"></script>")

      res.end "<!DOCTYPE html>#{$html.toString()}"

module.exports = App

