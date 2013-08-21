Ace = require '../index'
Cookies = require '../../cookies'
Outlet = require '../../utils/outlet'
Router = require '../../router'
Template = require '../../mvc/template'
Controller = require '../../mvc/controller'
ModelBase = require '../../mvc/model'
navigate = require '../../utils/navigate'
debug = global.debug 'ace'

module.exports = ->
  Ace['newClient'] = (json, $container) ->
    routesConfig = Ace['routes']
    Ace.initMVC()

    sock = global.io.connect '/'
    cookies = new Cookies sock
    cookies.get() # emits cookies

    globals =
      'cookies': cookies
      'session': session = new Outlet undefined, undefined, true
      'Model': class Model extends ModelBase
    ace = globals['ace'] =
      vars: {}
      acePath: ''
      aceComponents: {}
      'booting': true
      globals: globals

    Model.init ace, sock, json

    router = new Router Router.getRoutes(routesConfig), Router.getVars(routesConfig), globals, true
    ace.vars = router.vars
    ace.currentUrl = -> navigate.url

    # route only the URL the server saw when it rendered (to bootstrap)
    url = navigate.url.clone()
    url.reform hash: null
    router.route url

    Template.bootRoot = $container
    (new Controller['body'] ace)['appendTo'] $container
    ace['booting'] = false

    Model.clearQueryCache()
    delete Template.bootstrapRoot

    # now route the entire URL
    router.useNavigate()
    debug "DONE WITH EVENT LOOP"

