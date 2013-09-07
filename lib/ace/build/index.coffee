Cookies = require 'cookies-fork'
Outlet = require 'outlet'
Router = require '../../router'
debugError = global.debug 'ace:error'
debug = global.debug 'ace:server'
ModelBase = require '../../mvc/model'
Template = require '../../mvc/template'
Controller = require '../../mvc/controller'
Uri = require 'uri-fork'
setFormValues = require './set_form_values'
hash = (str) -> require('crypto').createHash('sha1').update(str).digest("hex")
bundleToHtml = require 'bundle-fork/to_html'
_ = require 'lodash-fork'
fs = require 'fs'

getInode = do ->
  cache = {}
  (filePath) -> cache[filePath] ||= fs.statSync(require.resolve filePath).ino

module.exports = (Ace) ->

  Ace.prototype._build = (manifest, bundleSpec, options, @sockEmulator) ->
    @bundleHtml = bundleToHtml bundleSpec, "-ie<=6 #{if options['release'] then 'release' else 'debug'}"
    @options = options
    clientManifest = @clientManifest =
      'template': manifest['template']
      'routes': getInode manifest['routes']

    require index if index = manifest['index']

    Template.add name, dom for name, dom of manifest['template']
    Template.compile()

    for type in ['model','view','controller']
      clazz = require("../../mvc/#{type}")
      cm = clientManifest[type] = {}
      for name,p of manifest[type]
        clazz.add name, require p
        cm[name] = getInode p
      clazz.compile()

    Router.buildRoutes @routes = require manifest['routes']

    ### original wrongPage code
      m = /^(?:[^:]*:\/\/)?(?:[^\/]*)?\/*(\/[^#]*)?#\d*\/*(\/[^#]*)?(#.*)?$/.exec window.location.href
      document.location.href = m[2] + (m[3] || '') if m and m[1] isnt m[2]
    # var a;(a=/^(?:[^:]*:\\/\\/)?(?:[^\\/]*)?\\/*(\\/[^#]*)?#\\d*\\/*(\\/[^#]*)?(#.*)?$/.exec(window.location.href))&&a[1]!==a[2]&&(document.location.href=a[2]+(a[3]||""));
    ###

    @$template = $ """
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
      @$template.find('head').append $ """
        <script type="text/javascript">
          window.DEBUG = #{_.quote(DEBUG)};
        </script>
        """

    return

  Ace.prototype.handle = (req, res, next, cb) ->
    debug "New request for #{req.originalUrl}"

    $html = @$template.clone()
    $body = $html.find 'body'
    $head = $html.find 'head'

    @sock = @sockEmulator()

    cookies = new Cookies @sock.serverSock, req, res
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
      ace.aceComponents = {}
      ace['globals'] = globals
      ace.uriToken = (uri) -> if id = session.value?.id then hash("#{id}#{uri}").substr(0,24) else ''

      Model.init ace

      ace.vars = (router = new Router @routes, globals).vars
      unless router.route uri = new Uri req.url
        cb?()
        return next null
      ace.currentUri = -> uri

      (new Controller['body'] ace)['appendTo'] $body
    catch _error
      debugError _error?.stack

    doRedirect = false

    @sock.onIdle idleFn = =>
      unless arr = uri?.query()['']
        try
          @sock.emit 'disconnect'
          json = Model.toJSON()
        catch _error
          debugError _error?.stack

        if doRedirect
          res.status 301
          res.setHeader "Location", router.matchOutlets()

        else if req.url isnt canonicalUri = router.serverUri().uri
          $head.prepend $ """<link rel="canonical" href="#{canonicalUri}"/>"""
        else
          canonicalUri = undefined

        $head.prepend $ @bundleHtml.head
        $body.append $ @bundleHtml.body
        $body.append $ """
          <script type="text/javascript">
            if (Ace) var ace = new Ace(#{_.quote(canonicalUri) || "null"}, #{JSON.stringify @clientManifest}, #{JSON.stringify json}, $('body'));
          </script>
          """
        res.end "<!DOCTYPE html>\n#{$html.toString()}"

        debug "done rendering request for #{req.originalUrl}"
        cb?()
        return

      doRedirect = true
      setFormValues $body, req.body if req.body

      try
        delete uri.query()['']
        uri.setQuery uri.query()
        validHash = arr[0] and ace.hash(uri.uri) is arr[0]
        @sock.serverSock.readOnly = !validHash

        return idleFn unless (compPath = arr?[1]) and (methName = arr[2])
        if component = ace.aceComponents[compPath]
          component[methName].apply component, arr[3..]
      catch _error
        debugError _error?.stack

      @sock.onIdle idleFn
      return

  return
