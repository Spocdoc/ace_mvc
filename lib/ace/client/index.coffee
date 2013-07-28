Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'
Template = require '../../mvc/template'
Controller = require '../../mvc/controller'
ModelBase = require '../../mvc/model'

module.exports = ->
  Ace['newClient'] = (json, $container) ->
    routesConfig = Ace.routes
    Ace.initMVC()

    sock = global.io.connect '/'
    cookies = new Cookies sock
    sock.emit 'cookies', cookies.toJSON(), ->

    globals =
      'cookies': cookies
      'session': session = new Outlet undefined, undefined, true
      'Model': class Model extends ModelBase
    ace = globals['ace'] =
      aceName: 'ace'
      'aceName': 'ace'
      'booting': true
      'globals': globals

    Model.init globals, sock, json

    ace.vars = new Router(Router.getRoutes(routesConfig), Router.getVars(routesConfig), globals, true).vars

    Template.bootRoot = $container

    (new Controller['body'] ace)['appendTo'] $container

    ace['booting'] = false

    Model.clearQueryCache()

    delete Template.bootstrapRoot

