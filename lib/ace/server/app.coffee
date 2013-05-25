fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
Url = require '../../url'
OJSON = require '../../ojson'

directories = (path) ->
  dir for dir in fs.readdirSync path when fs.statSync("#{path}/#{dir}").isDirectory()

# express sets route, parent
class App
  constructor: (settings) ->
    # TODO: is this really the only way to extend express. wtf
    extend @, express()
    delete @handle

    extend @settings, settings
    @on 'mount', (app) => @_configure(app)

  _configure: (app) ->
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

    @bundler = @settings.bundler
    @bundler.set 'debug', @settings['debug']
    @bundler.set 'routes', @settings['routes']
    @bundler.set 'globals',
      'Ace': path.resolve(__dirname, '../../ace')
    @bundler.start()
    return

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

    # add client-side script
    @bundler.getUris (debugUris, releaseUris) =>
      for uri in (if @settings['debug'] then debugUris else releaseUris)
        $html.append $("<script type=\"text/javascript\" src=\"#{uri}\"></script>")

      $html.append $("""
      <script type=\"text/javascript\">
      (function () {
        var historyOutlets = #{OJSON.stringify ace.historyOutlets};
        var ace = new window.Ace(OJSON.fromOJSON(historyOutlets));
        ace.routing.enable(require('routes'));
        var navigator = ace.routing.enableNavigator();
        ace.routing.router.route(navigator.url);
        ace.appendTo($('html'));
      }());
      </script>
      """)

      res.end "<!DOCTYPE html>\n#{$html.toString()}"

module.exports = App

