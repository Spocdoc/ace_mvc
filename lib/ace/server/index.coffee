Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'
debug = global.debug 'ace:error'
ModelBase = require '../../mvc/model'

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    sock = global.io.connect '/'

    globals =
      app:
        'cookies': cookies = new Cookies req, res
        'session': session = new Outlet undefined, undefined, true
        'Model': class Model extends ModelBase
      Template:
        $root: $container

    sock.emit 'cookies', cookies.toJSON(), ->
    Model.init globals, sock

    try
      (router = new Router routes, vars, globals, false).route req.url
      ace = new Ace globals, router
    catch _error
      debug _error?.stack

    sock.onIdle ->
      sock.emit 'disconnect'
      cb null, Model.toJSON()
