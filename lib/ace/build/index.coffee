Cookies = require 'cookies-fork'
Outlet = require 'outlet'
Router = require '../../router'
debugError = global.debug 'ace:error'
debug = global.debug 'ace:server'
ModelBase = require '../../mvc/model'
Template = require '../../mvc/template'
Controller = require '../../mvc/controller'
Uri = require 'uri-fork'
template = require '../../template'
setFormValues = require './set_form_values'
hash = require 'hash-fork'
path = require 'path'
_ = require 'lodash-fork'
fs = require 'fs'
beautify = require 'js-beautify'

stringify = (json) ->
  JSON.stringify(json).replace(/<\/script>/ig,'''</scr"+"ipt>''')

unless process.env.NODE_ENV is 'production'
  prodStringify = stringify
  stringify = (json) ->
    beautify(prodStringify(json).replace(/<\/script>/ig,'''</scr"+"ipt>'''),wrap_line_length: 70)

module.exports = (Ace) ->

  Ace.prototype._build = (manifest, @options, @sockEmulator) ->
    @skipJS = manifest.options.disableClientJS
    @bundleHtml = manifest.clientHtml(skipJS: @skipJS)

    {root, assetRoot: @assetRoot} = manifest.private
    release = process.env.NODE_ENV is 'production'

    if relPath = manifest.options.templateGlobals
      @templateGlobals = require(path.resolve root, relPath)(manifest)

    clientManifest = @clientManifest =
      routes: _.getInodeSync require.resolve path.resolve(root, manifest.routes)
      templates: templates = {}
      templateGlobals: @templateGlobals
      assetServerRoot: manifest.options.assetServerRoot
      uploadsServerRoot: manifest.options.uploadsServerRoot

    clientManifest.cookies = cookies if cookies = options.cookies

    for name, relPath of manifest.templates
      templates[name] = html = template path.resolve(root,relPath), name, @templateGlobals
      Template.add name, html

    Template.compile()

    require path.resolve(root,index) if index = manifest.index

    # add all the mixins to the client manifest
    cm = clientManifest["mixins"] = {}
    mixins = {}
    for name, relPath of manifest["mixins"]
      fullPath = path.resolve root, relPath
      cm[name] = _.getInodeSync fullPath
      mixins[name] = require fullPath

    # build each type, adding mixins and adding each to the client manifest
    for type in ['model','view','controller']
      clazz = require("../../mvc/#{type}")
      cm = clientManifest["#{type}s"] = {}
      clazz.add name, mixin for name, mixin of mixins
      for name, relPath of manifest["#{type}s"]
        fullPath = path.resolve root, relPath
        clazz.add name, require fullPath
        cm[name] = _.getInodeSync fullPath
      clazz.compile()

    Router.buildRoutes @routes = require path.resolve(root, manifest.routes)

    @$template = $template = $ if layout = manifest.layout then """<html>#{template path.resolve(root,layout), '', @templateGlobals}</html>""" else """
      <html><!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title></title></head><body></body></html></html>
      """

    $html = $template.find 'html'
    $head = $html.find 'head'

    ### original wrongPage code
      m = /^(?:[^:]*:\/\/)?(?:[^\/]*)?\/*(\/[^#]*)?#\d*\/*(\/[^#]*)?(#.*)?$/.exec window.location.href
      document.location.href = m[2] + (m[3] || '') if m and m[1] isnt m[2]
    # var a;(a=/^(?:[^:]*:\\/\\/)?(?:[^\\/]*)?\\/*(\\/[^#]*)?#\\d*\\/*(\\/[^#]*)?(#.*)?$/.exec(window.location.href))&&a[1]!==a[2]&&(document.location.href=a[2]+(a[3]||""));
    ###
    $head.append """
      <script type="text/javascript">(function (){var a;(a=/^(?:[^:]*:\\/\\/)?(?:[^\\/]*)?\\/*(\\/[^#]*)?#\\d*\\/*(\\/[^#]*)?(#.*)?$/.exec(window.location.href))&&a[1]!==a[2]&&(document.location.href=a[2]+(a[3]||""));}());</script>
      """

    if !release and DEBUG = process.env.DEBUG
      $head.append $ """
        <script type="text/javascript">
          window.DEBUG = #{_.quote(DEBUG)};
        </script>
        """

    @clientManifestString = stringify(@clientManifest)

    return

  Ace.prototype.handle = (req, res, next) ->
    debug "New request for #{req.originalUrl}"

    if req.url.lastIndexOf('/pub/') is 0
      filePath = path.resolve(@assetRoot, req.url.replace(/^\/pub\/+/,''))
      return next() unless filePath.lastIndexOf(@assetRoot+"/") is 0
      _.readFile filePath, (err, content) =>
        return next() if err?
        res.end content
      return

    $doc = @$template.clone()
    $html = $doc.find 'html'
    $body = $html.find 'body'
    $head = $html.find 'head'
    $title = $head.find 'title'

    @sock = @sockEmulator()

    cookies = new Cookies @sock.serverSock, req, res, @options.cookies

    @sock.emit 'cookies', cookies.toJSON(), ->

    try
      globals =
        'cookies': cookies
        'session': session = new Outlet undefined, undefined, true
        'Model': class Model extends ModelBase
        'templates': @templateGlobals

      ace = globals['ace'] = Object.create this
      ace.aceComponents = {}
      ace['manifest'] = ace.manifest = @clientManifest
      ace['globals'] = globals
      ace['onServer'] = true
      ace.uriToken = (uri) -> if id = session.value?.id then hash("#{id}#{uri}").substr(0,24) else ''

      Model.init ace
      Model.attachSocketHandlers this

      ace.vars = (router = new Router @routes, globals).vars
      return next null unless router.route uri = new Uri req.url
      ace.currentUri = -> uri

      (new Controller['body'] ace)['appendTo'] $body
    catch _error
      debugError _error?.stack

    doRedirect = false
    res.header 'Content-Type', 'text/html'

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

        unless @skipJS
          $html.append $ """
            <script type="text/javascript">
              window.aceArgs = [#{_.quote(canonicalUri) || "null"}, #{@clientManifestString}, #{stringify(json)}, 'body'];
            </script>
            """

        $title.after $ str if str = @bundleHtml.head
        $body.append $ str if str = @bundleHtml.body
        $html.append $ str if str = @bundleHtml.html

        res.end ''+$doc.html()

        debug "done rendering request for #{req.originalUrl}"
        return

      doRedirect = true
      setFormValues $body, req if req.body or req.files

      try
        delete uri.query()['']
        uri.setQuery uri.query()
        validHash = arr[0] and ace.uriToken(uri.uri) is arr[0]
        @sock.serverSock.readOnly = !validHash

        return idleFn unless (compPath = arr?[1]) and (methName = arr[2])
        if component = ace.aceComponents[compPath]
          component[methName].apply component, arr[3..]
      catch _error
        debugError _error?.stack

      @sock.onIdle idleFn
      return

  return
