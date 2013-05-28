fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
Url = require '../../url'
OJSON = require '../../ojson'
Bundler = require '../../bundler/server'

quote = do ->
  regexQuotes = /(['\\])/g
  regexNewlines = /([\n])/g
  (str) ->
    '\''+str.replace(regexQuotes,'\\$1').replace(regexNewlines,'\\n')+'\''

# express sets route, parent
class App
  constructor: (@bundler, settings) ->
    extend @, express()
    delete @handle
    extend @settings, settings

  boot: (cb) ->
    app = @parent

    Template = require '../../mvc/template'
    View = require '../../mvc/view'
    Controller = require '../../mvc/controller'

    mvc = @settings.mvc

    Template.add name, dom for name, dom of mvc['template']
    View.add name, require p for name, p of mvc['view']
    Controller.add name, require p for name, p of mvc['controller']

    Routing = require '../routing'
    @_routeConfig = require(@settings['routes'])
    @_routes = Routing.buildRoutes @_routeConfig

    @$html = $("""
    <html>
        <head>
            <title></title>
        </head>
    </html>
    """)

    if @settings.debug and debug = process.env.DEBUG
      @$html.find('head').append $("""
        <script type="text/javascript">
          window.DEBUG = #{quote(debug)};
        </script>""")

    cb()

  handle: (req, res, next) ->
    Ace = require '../index'
    Template = require '../../mvc/template'

    ace = new Ace
    ace.routing.enable @_routeConfig, @_routes

    $html = @$html.clone()
    $head = $html.find 'head'

    ace.routing.router.route req.url
    ace.appendTo($html)
    uris = (if @settings['debug'] then @bundler.debugUris else @bundler.releaseUris)

    $body = $html.find 'body'

    # add client-side script
    for uri in uris.js
      $body.append $("""<script type="text/javascript" src="#{uri}"></script>""")

    for uri in uris.css
      $head.prepend $("""<link href="#{uri}" rel="stylesheet" type="text/css"/>""")

    $body.append $("""
    <script type="text/javascript">
    (function () {
      var historyOutlets = #{OJSON.stringify ace.historyOutlets};
      window.Ace.newClient(historyOutlets, require('routes'), $('html'));
    }());
    </script>
    """)

    res.end "<!DOCTYPE html>\n#{$html.toString()}"

module.exports = App

