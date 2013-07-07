fs = require 'fs'
path = require 'path'
express = require 'express'
{extend} = require '../utils/mixin'
Url = require '../utils/url'
OJSON = require '../utils/ojson'
quote = require '../utils/quote'

# express sets route, parent
class App
  constructor: (@bundler, settings) ->
    extend @, express()
    delete @handle
    extend @settings, settings

  boot: (cb) ->
    app = @settings.app

    require('../mvc/template').add name, dom for name, dom of app['template']

    for type in ['model','view','controller']
      clazz = require("../mvc/#{type}")
      clazz.add name, require p for name,p of app[type]
      clazz.finish()

    router = require '../router'
    routes = require @settings['routes']
    @_routes = router.getRoutes routes
    @_vars = router.getVars routes

    ### original wrongPage code
    var a = !window.history || !window.history.pushState, b = window.location.pathname.slice(1);
    window['wrongPage'] = window.location.hash.match(/^#\\d+(.*)/);
    if (window['wrongPage'] && window['wrongPage'][1] === window.location.pathname) window['wrongPage'] = false;
    a && (window['wrongPage'] && b) && (document.location.href = window['wrongPage'][1]);
    ###

    @$html = $("""
    <html>
    <head>
    <title></title>
    <script type="text/javascript">
    (function () {var a=!window.history||!window.history.pushState,b=window.location.pathname.slice(1);window.wrongPage=window.location.hash.match(/^#\\d+(.*)/);window.wrongPage&&window.wrongPage[1]===window.location.pathname&&(window.wrongPage=!1);a&&window.wrongPage&&b&&(document.location.href=window.wrongPage[1]);})();
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
    Ace = require '../ace'
    $html = @$html.clone()
    $body = $html.find 'body'
    $head = $html.find 'head'

    Ace.newServer req, res, next, $body, @_routes, @_vars, (err, ace) =>
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

      $body.append $("""
      <script type="text/javascript">
      (function () {
        var restore = window.wrongPage ? null : #{OJSON.stringify ace};
        window.Ace.newClient(restore, require('routes'), $('body'));
      }());
      </script>
      """)

      res.end "<!DOCTYPE html>\n#{$html.toString()}"
      return

    return

module.exports = App
