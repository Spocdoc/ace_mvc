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

    router = new Router Router.getRoutes(routesConfig), Router.getVars(routesConfig), globals, true
    ace.vars = router.vars

    # route only the URL the server saw when it rendered (to bootstrap)
    url = router.navigator.url.clone()
    url.reform hash: null
    router.route url

    Template.bootRoot = $container
    (new Controller['body'] ace)['appendTo'] $container
    ace['booting'] = false

    Model.clearQueryCache()
    delete Template.bootstrapRoot

    # now route the entire URL
    router.useNavigator()

