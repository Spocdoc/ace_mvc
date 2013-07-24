Ace = require '../index'
Cookies = require '../../utils/cookies'
router = require '../../router'

module.exports = ->

  Ace['newClient'] = (json, $container) ->
    routesConfig = Ace.routes
    Ace.initMVC()

    sock = global.io.connect '/'

    globals =
      app:
        'cookies': cookies = new Cookies
        'session': new Outlet
        'Model': class Model extends require('../../mvc/model')
      Template:
        $root: $container

    Model.init globals, sock, json
    sock.emit 'cookies', cookies.toJSON()

    new Ace globals, new Router Router.getRoutes(routesConfig), Router.getVars(routesConfig), globals, true
