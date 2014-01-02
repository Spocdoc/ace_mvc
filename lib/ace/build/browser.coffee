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

  Ace.prototype._build = (canonicalUri, manifest, json, containerSelector) ->
    $container = $ containerSelector
    Template.add name, dom for name, dom of manifest['templates']
    ModelBase.add name, global['req'+exp] for name, exp of manifest['models']
    View.add name, global['req'+exp] for name, exp of manifest['views']
    Controller.add name, global['req'+exp] for name, exp of manifest['controllers']

    Template.compile()
    ModelBase.compile()
    View.compile()
    Controller.compile()

    sock = io.connect '/'
    cookies = new Cookies sock
    cookies.get() # emits cookies

    sock.once 'disconnect', =>
      sock.on 'connect', =>
        sock.emit 'cookies', cookies.toJSON(), ->
        Model['reread']()

    globals =
      'cookies': cookies
      'session': session = new Outlet undefined, undefined, true
      'Model': class Model extends ModelBase
      'ace': this
      'templates': manifest['templateGlobals']

    @['booting'] = true
    globals['globals'] = globals
    @globals = globals
    @sock = sock
    # @aceComponents = {}

    Model.init this, json

    router = new Router global['req'+manifest['routes']], globals
    navigate.enable()

    @vars = router.vars
    @currentUri = -> navigate.uri

    # route only the URL the server saw when it rendered (to bootstrap)
    router.route canonicalUri || navigate.uri.clone().setHash('')

    Template.bootRoot = $container
    (new Controller['body'] this)['appendTo'] $container
    @['booting'] = false
    Template.bootRoot = null

    Model.clearQueryCache()
    delete Template.bootstrapRoot

    # now route the entire URL
    router.useNavigate canonicalUri
    debug "DONE WITH EVENT LOOP"

