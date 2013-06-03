fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
Url = require '../../url'
OJSON = require '../../ojson'
Bundler = require '../../bundler/server'
Cascade = undefined
Cookies = undefined

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

    Cascade = require '../../cascade/cascade'
    Template = require '../../mvc/template'
    View = require '../../mvc/view'
    Controller = require '../../mvc/controller'
    Cookies = require '../../cookies'

    mvc = @settings.mvc

    Template.add name, dom for name, dom of mvc['template']
    View.add name, require p for name, p of mvc['view']
    Controller.add name, require p for name, p of mvc['controller']

    Routing = require '../routing'
    @_routeConfig = require(@settings['routes'])
    @_routes = Routing.buildRoutes @_routeConfig

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

  _finish: (ace, $html, res, next) ->
    $head = $html.find 'head'
    $body = $html.find 'body'

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

  handle: (req, res, next) ->
    cc = Cascade.newContext()

    Ace = require '../index'
    Template = require '../../mvc/template'

    ace = new Ace
    ace.cookies = new Cookies req, res
    ace.routing.enable @_routeConfig, @_routes

    $html = @$html.clone()

    ace.routing.router.route req.url
    ace.appendTo($html.find('body'))

    if cc.pending
      Cascade.on 'done', =>
        process.nextTick =>
          @_finish ace, $html, res, next
    else
      @_finish ace, $html, res, next

    return

module.exports = App

