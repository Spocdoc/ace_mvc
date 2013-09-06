Cookies = require 'cookies-fork'
Outlet = require 'outlet'
Router = require '../../router'
Template = require '../../mvc/template'
Model = require '../../mvc/model'
View = require '../../mvc/view'
Controller = require '../../mvc/controller'
ModelBase = require '../../mvc/model'
io = require 'sockio-fork'
navigate = require 'navigate-fork'
debug = global.debug 'ace'

module.exports = (Ace) ->

  Ace.prototype._build = (canonicalUrl, manifest, json, $container) ->
    Template.add name, dom for name, dom of manifest['template']
    ModelBase.add name, global['req'+exp] for name, exp of manifest['model']
    View.add name, global['req'+exp] for name, exp of manifest['view']
    Controller.add name, global['req'+exp] for name, exp of manifest['controller']

    Template.compile()
    ModelBase.compile()
    View.compile()
    Controller.compile()

    sock = io.connect '/'
    cookies = new Cookies sock
    cookies.get() # emits cookies

    globals =
      'cookies': cookies
      'session': session = new Outlet undefined, undefined, true
      'Model': class Model extends ModelBase
      'ace': this

    @['booting'] = true
    @['globals'] = globals
    @['sock'] = sock
    @aceComponents = {}

    Model.init this, json

    router = new Router global['req'+manifest['routes']], globals
    navigate.enable()

    @vars = router.vars
    @currentUrl = -> navigate.url

    # route only the URL the server saw when it rendered (to bootstrap)
    router.route canonicalUrl || navigate.url.clone().reform hash: null

    Template.bootRoot = $container
    (new Controller['body'] this)['appendTo'] $container
    @['booting'] = false

    Model.clearQueryCache()
    delete Template.bootstrapRoot

    # now route the entire URL
    router.useNavigate canonicalUrl
    debug "DONE WITH EVENT LOOP"

