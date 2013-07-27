Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'

module.exports = ->

  Ace['newClient'] = (json, $container) ->
    routesConfig = Ace.routes
    Ace.initMVC()

    sock = global.io.connect '/'

    globals =
      app:
        'cookies': cookies = new Cookies sock
        'session': session = new Outlet undefined, undefined, true
        'Model': class Model extends require('../../mvc/model')
      Template:
        $root: $container

    sock.emit 'cookies', cookies.toJSON(), ->
    Model.init globals, sock, json

    new Ace globals, new Router Router.getRoutes(routesConfig), Router.getVars(routesConfig), globals, true
