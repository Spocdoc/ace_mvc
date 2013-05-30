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
    <script type="text/javascript">
    (function () {
    var a = !window.history || !window.history.pushState, b = window.location.pathname.slice(1);
    window.wrongPage = window.location.hash.match(/^#\\d+(.*)/);
    a && (window.wrongPage && b) && (document.location.href = hashPath[1]);
    })();
    </script>
    </head>
    <body></body>
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
    $body = $html.find 'body'

    ace.routing.router.route req.url
    ace.appendTo($body)
    uris = (if @settings['debug'] then @bundler.debugUris else @bundler.releaseUris)

    $body.prepend $("""
    <script type="text/javascript">
      window.wrongPage && document.write('<div id="wrong-page" style="display:none">');
    </script
    """)

    $body.append $("""
    <script type="text/javascript">
    (function () {
    if (window.wrongPage) {
      document.write("</div>");
      var a = document.getElementById("wrong-page");
      a.parentNode.removeChild(a)
    }
    })();
    </script>
    """)

    # add client-side script
    for uri in uris.js
      $body.append $("""<script type="text/javascript" src="#{uri}"></script>""")

    for uri in uris.css
      $head.prepend $("""<link href="#{uri}" rel="stylesheet" type="text/css"/>""")

    # TODO: also restore the models
    $body.append $("""
    <script type="text/javascript">
    (function () {
      var historyOutlets = #{OJSON.stringify ace.historyOutlets};
      window.Ace.newClient(historyOutlets, require('routes'), $('body'));
    }());
    </script>
    """)

    res.end "<!DOCTYPE html>\n#{$html.toString()}"

module.exports = App

