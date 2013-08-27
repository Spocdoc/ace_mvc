Ace = require '../index'
Cookies = require 'cookies-fork'
Outlet = require 'outlet'
Router = require '../../router'
Template = require '../../mvc/template'
Model = require '../../mvc/model'
View = require '../../mvc/view'
Controller = require '../../mvc/controller'
ModelBase = require '../../mvc/model'
navigate = require '../../utils/navigate'
debug = global.debug 'ace'

module.exports = ->
  Ace.newClient = (manifest, json, $container) ->
    Template.add name, dom for name, dom of manifest['template']
    ModelBase.add name, global['req'+exp] for name, exp of manifest['model']
    View.add name, global['req'+exp] for name, exp of manifest['view']
    Controller.add name, global['req'+exp] for name, exp of manifest['controller']

    Template.compile()
    ModelBase.compile()
    View.compile()
    Controller.compile()

    sock = global.io.connect '/'
    cookies = new Cookies sock
    cookies.get() # emits cookies

    globals =
      'cookies': cookies
      'session': session = new Outlet undefined, undefined, true
      'Model': class Model extends ModelBase

    ace = globals['ace'] = new Ace
    ace['booting'] = true
    ace['globals'] = globals
    ace['sock'] = sock

    Model.init ace, json

    router = new Router global['req'+manifest['routes']], globals
    navigate.enable()

    ace.vars = router.vars
    ace.currentUrl = -> navigate.url

    # route only the URL the server saw when it rendered (to bootstrap)
    router.route navigate.url.clone().reform hash: null

    Template.bootRoot = $container
    (new Controller['body'] ace)['appendTo'] $container
    ace['booting'] = false

    Model.clearQueryCache()
    delete Template.bootstrapRoot

    # now route the entire URL
    router.useNavigate()
    debug "DONE WITH EVENT LOOP"

