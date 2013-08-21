Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'
debugError = global.debug 'ace:error'
debug = global.debug 'ace:server'
ModelBase = require '../../mvc/model'
Controller = require '../../mvc/controller'
Url = require '../../utils/url'
setFormValues = require './set_form_values'
hash = (str) -> require('crypto').createHash('sha1').update(str).digest("hex")

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    sock = global.io.connect '/'
    cookies = new Cookies req, res, sock.serverSock
    sock.emit 'cookies', cookies.toJSON(), ->
    debug "New request for #{req.originalUrl}"

    try
      globals =
        'cookies': cookies
        'session': session = new Outlet undefined, undefined, true
        'Model': class Model extends ModelBase
      ace = globals['ace'] =
        vars: {}
        acePath: ''
        aceComponents: {}
        'globals': globals
        hash: (href) ->
          if id = session.value?.id
            hash("#{id}#{href}").substr(0,24)

      Model.init ace, sock

      router = new Router routes, vars, globals, false
      router.route req.url
      ace.vars = router.vars
      url = new Url req.url, slashes: false
      ace.currentUrl = -> url

      (new Controller['body'] ace)['appendTo'] $container
    catch _error
      debugError _error?.stack

    doRedirect = false

    sock.onIdle idleFn = ->
      unless arr = url?.query?['']
        try
          sock.emit 'disconnect'
          json = Model.toJSON()
        catch _error
          debugError _error?.stack

        redirect = if doRedirect then router.matchOutlets() else ''
        debug "done rendering request for #{req.originalUrl}"
        cb null, json, redirect
        return

      doRedirect = true
      setFormValues $container, req.body if req.body

      try
        delete url.query['']
        url.reform query: url.query
        validHash = arr[0] and ace.hash(url.href) is arr[0]
        sock.serverSock.readOnly = !validHash

        return idleFn unless (compPath = arr?[1]) and (methName = arr[2])
        if component = ace.aceComponents[compPath]
          component[methName].apply component, arr[3..]
      catch _error
        debugError _error?.stack

      sock.onIdle idleFn
      return



