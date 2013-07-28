Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'
debug = global.debug 'ace:error'
ModelBase = require '../../mvc/model'
Controller = require '../../mvc/controller'

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    cookies = new Cookies req, res
    (sock = global.io.connect '/').emit 'cookies', cookies.toJSON(), ->

    try
      globals =
        'cookies': cookies
        'session': session = new Outlet undefined, undefined, true
        'Model': class Model extends ModelBase
      ace = globals['ace'] =
        aceName: 'ace'
        'aceName': 'ace'
        'globals': globals

      Model.init globals, sock

      router = new Router routes, vars, globals, false
      router.route req.url
      ace.vars = router.vars

      (new Controller['body'] ace)['appendTo'] $container
    catch _error
      debug _error?.stack

    sock.onIdle ->
      sock.emit 'disconnect'
      cb null, Model.toJSON()
