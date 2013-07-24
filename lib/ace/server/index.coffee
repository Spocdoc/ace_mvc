Ace = require '../index'
Cookies = require '../../utils/cookies'
Outlet = require '../../outlet'
Router = require '../../router'
debug = global.debug 'ace:error'

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    sock = global.io.connect '/'

    globals =
      app:
        'cookies': cookies = new Cookies req, res
        'session': session = new Outlet
        'Model': class Model extends require('../../mvc/model')
      Template:
        $container: $container

    Model.init globals, sock
    sock.emit 'cookies', cookies.toJSON()

    try
      (router = new Router routes, vars, globals, false).route req.url
      ace = new Ace globals, router
    catch _error
      debug _error?.stack

    sock.onIdle ->
      sock.emit 'disconnect'
      cb null, Model.toJSON()
