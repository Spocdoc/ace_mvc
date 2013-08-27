Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'
debugError = global.debug 'ace:error'
debug = global.debug 'ace:server'
ModelBase = require '../../mvc/model'
Url = require '../../utils/url'
setFormValues = require './set_form_values'
hash = (str) -> require('crypto').createHash('sha1').update(str).digest("hex")

getInode = do ->
  cache = {}
  (filePath) -> cache[filePath] ||= fs.statSync(filePath).ino

module.exports = ->

  Ace.newServer = (manifest, bundleSpec, options, sockEmulator) ->
    ace = new Ace
    ace.sock = sockEmulator
    ace.bundleSpec = bundleSpec
    ace.options = options
    clientManifest = ace.clientManifest =
      'template': manifest['template']
      'routes': getInode manifest['routes']

    Template.add name, dom for name, dom of manifest['template']
    Template.compile()

    for type in ['model','view','controller']
      clazz = require("../../mvc/#{type}")
      cm = clientManifest[type] = {}
      for name,p of manifest[type]
        clazz.add name, require p
        cm[name] = getInode p
      clazz.compile()

    Router.buildRoutes ace.routes = require manifest['routes']

    ### original wrongPage code
      m = /^(?:[^:]*:\/\/)?(?:[^\/]*)?\/*(\/[^#]*)?#\d*\/*(\/[^#]*)?(#.*)?$/.exec window.location.href
      document.location.href = m[2] + (m[3] || '') if m and m[1] isnt m[2]
    # var a;(a=/^(?:[^:]*:\\/\\/)?(?:[^\\/]*)?\\/*(\\/[^#]*)?#\\d*\\/*(\\/[^#]*)?(#.*)?$/.exec(window.location.href))&&a[1]!==a[2]&&(document.location.href=a[2]+(a[3]||""));
    ###

    ace.$template = $ """
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
      """

    if process.env.NODE_ENV isnt 'production' and DEBUG = process.env.DEBUG
      ace.$template.find('head').append $ """
        <script type="text/javascript">
          window.DEBUG = #{_.quote(DEBUG)};
        </script>
        """

    ace

  Ace.prototype.writeResponse = ($html, $head, $body, json, res) ->
    # TODO: make this generic -- it should determine the appropriate conditional comments using @bundleSpec keys

    uris = @bundleSpec

    $head.prepend $ """<link href="#{uri}" rel="stylesheet" type="text/css"/>""" for uri in uris.css.standard

    if uris.js.ie6
      cond = """<!--[if lte IE 7]>"""
      cond += """<script type="text/javascript" src="#{uri}"></script>""" for uri in uris.js.ie6
      cond += """<![endif]-->"""
      $body.append cond

    if uris.js.ie8
      cond = """<!--[if IE 8]>"""
      cond += """<script type="text/javascript" src="#{uri}"></script>""" for uri in uris.js.ie8
      cond += """<![endif]-->"""
      $body.append cond

    cond = """<![if gt IE 8]>"""
    cond += """<script type="text/javascript" src="#{uri}"></script>""" for uri in uris.js.standard
    cond += """<![endif]>"""
    $body.append cond

    $body.append $ """
      <script type="text/javascript">
      ace && (ace.body = ace(#{JSON.stringify @clientManifest}, #{JSON.stringify json}, $('body')));
      </script>
      """

    res.end "<!DOCTYPE html>\n#{$html.toString()}"
    return

  Ace.prototype.handle = (req, res, next, cb) ->
    debug "New request for #{req.originalUrl}"

    $html = @$template.clone()
    $body = $html.find 'body'
    $head = $html.find 'head'

    cookies = new Cookies req, res, @sock.serverSock
    if oc = @options.cookies
      cookies.domain = oc['domain']
      cookies.secure = oc['secure']

    @sock.emit 'cookies', cookies.toJSON(), ->

    try
      globals =
        'cookies': cookies
        'session': session = new Outlet undefined, undefined, true
        'Model': class Model extends ModelBase

      ace = globals['ace'] = Object.create this
      ace['globals'] = globals
      ace.hash = (href) -> hash("#{id}#{href}").substr(0,24) if id = session.value?.id

      Model.init ace

      ace.vars = (router = new Router @routes, globals).vars
      unless router.route url = new Url req.url, slashes: false
        cb?()
        return next null
      ace.currentUrl = -> url

      (new Controller['body'] ace)['appendTo'] $body
    catch _error
      debugError _error?.stack

    doRedirect = false

    @sock.onIdle idleFn = =>
      unless arr = url?.query?['']
        try
          @sock.emit 'disconnect'
          json = Model.toJSON()
        catch _error
          debugError _error?.stack

        if doRedirect
          res.status 301
          res.setHeader "Location", router.matchOutlets()

        @writeResponse $html, $head, $body, json, res
        debug "done rendering request for #{req.originalUrl}"
        cb?()
        return

      doRedirect = true
      setFormValues $body, req.body if req.body

      try
        delete url.query['']
        url.reform query: url.query
        validHash = arr[0] and ace.hash(url.href) is arr[0]
        @sock.serverSock.readOnly = !validHash

        return idleFn unless (compPath = arr?[1]) and (methName = arr[2])
        if component = ace.aceComponents[compPath]
          component[methName].apply component, arr[3..]
      catch _error
        debugError _error?.stack

      @sock.onIdle idleFn
      return

