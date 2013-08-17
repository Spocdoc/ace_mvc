fs = require 'fs'
path = require 'path'
express = require 'express'
{extend} = require '../utils/mixin'
Url = require '../utils/url'
OJSON = require '../utils/ojson'
quote = require '../utils/quote'
Ace = undefined

# express sets route, parent
class App
  constructor: (@bundler, settings) ->
    extend @, express()
    delete @handle
    extend @settings, settings

  boot: (cb) ->
    Ace = require '../ace'
    app = @settings.app

    Template = require('../mvc/template')
    Template.add name, dom for name, dom of app['template']
    Template.finish()

    for type in ['model','view','controller']
      clazz = require("../mvc/#{type}")
      clazz.add name, require p for name,p of app[type]
      clazz.finish()

    router = require '../router'
    routes = require @settings['routes']
    @_routes = router.getRoutes routes
    @_vars = router.getVars routes

    ### original wrongPage code
      m = /^(?:[^:]*:\/\/)?(?:[^\/]*)?\/*(\/[^#]*)?#\d*\/*(\/[^#]*)?(#.*)?$/.exec window.location.href
      document.location.href = m[2] + (m[3] || '') if m and m[1] isnt m[2]
    # var a;(a=/^(?:[^:]*:\\/\\/)?(?:[^\\/]*)?\\/*(\\/[^#]*)?#\\d*\\/*(\\/[^#]*)?(#.*)?$/.exec(window.location.href))&&a[1]!==a[2]&&(document.location.href=a[2]+(a[3]||""));
    ###

    @$html = $("""
    <html>
    <head>
    <meta charset="UTF-8"/>
    <title></title>
    <script type="text/javascript">
    (function (){
      var a;(a=/^(?:[^:]*:\\/\\/)?(?:[^\\/]*)?\\/*(\\/[^#]*)?#\\d*\\/*(\\/[^#]*)?(#.*)?$/.exec(window.location.href))&&a[1]!==a[2]&&(document.location.href=a[2]+(a[3]||""));
    }());
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
    $html = @$html.clone()
    $body = $html.find 'body'
    $head = $html.find 'head'

    Ace.newServer req, res, next, $body, @_routes, @_vars, (err, json, redirect) =>
      if redirect
        res.status 301
        res.setHeader "Location", redirect

      uris = (if @settings['debug'] then @bundler.debugUris else @bundler.releaseUris)

      # IE 6 script: by default, not supported with scripting (just server-side
      # render). all scripts are excluded unless explicitly added to ie6
      # category
      if uris.js.ie6
        cond = """<!--[if lte IE 7]>"""
        for uri in uris.js.ie6
          cond += """<script type="text/javascript" src="#{uri}"></script>"""
        cond += """<![endif]-->"""
        $body.append cond

      if uris.js.ie8
        cond = """<!--[if IE 8]>"""
        for uri in uris.js.ie8
          cond += """<script type="text/javascript" src="#{uri}"></script>"""
        cond += """<![endif]-->"""
        $body.append cond

      cond = """<![if gt IE 8]>"""
      cond += """<script type="text/javascript" src="#{uri}"></script>""" for uri in uris.js.standard
      cond += """<![endif]>"""
      $body.append cond

      for uri in uris.css.standard
        $head.prepend $("""<link href="#{uri}" rel="stylesheet" type="text/css"/>""")

      $body.append $("""
      <script type="text/javascript">
      (function () {
        var restore = #{JSON.stringify json};
        if (window.Ace) window.ace = window.Ace.newClient(restore, $('body'));
      }());
      </script>
      """)

      res.end "<!DOCTYPE html>\n#{$html.toString()}"
      return

    return

module.exports = App

