Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'
debugError = global.debug 'ace:error'
debug = global.debug 'ace:server'
ModelBase = require '../../mvc/model'
Controller = require '../../mvc/controller'
Url = require '../../utils/url'

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    cookies = new Cookies req, res
    (sock = global.io.connect '/').emit 'cookies', cookies.toJSON(), ->
    debug "New request for #{req.originalUrl}"

    try
      globals =
        'cookies': cookies
        'session': session = new Outlet undefined, undefined, true
        'Model': class Model extends ModelBase
      ace = globals['ace'] =
        aceName: 'ace'
        vars: {}
        acePath: ''
        aceComponents: {}
        'aceName': 'ace'
        'globals': globals

      Model.init ace, sock

      router = new Router routes, vars, globals, false
      router.route req.url
      ace.vars = router.vars
      url = new Url req.url, slashes: false
      ace.currentUrl = -> url

      (new Controller['body'] ace)['appendTo'] $container
    catch _error
      debugError _error?.stack

    sock.onIdle idleFn = ->
      unless arr = url?.query?['']
        try
          sock.emit 'disconnect'
          json = Model.toJSON()
        catch _error
          debugError _error?.stack
        cb null, json
        return

      try
        delete url.query['']
        return idleFn unless (pathName = arr?[0]) and (methName = arr[1])
        if component = ace.aceComponents[arr[0]]
          component[methName].apply component, arr[2..]
      catch _error
        debugError _error?.stack

      sock.onIdle idleFn
      return



