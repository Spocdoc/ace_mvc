Cookies = require 'cookies-fork'
Outlet = require 'outlet'
Router = require '../../router'
Template = require '../../mvc/template'
Model = require '../../mvc/model'
View = require '../../mvc/view'
Controller = require '../../mvc/controller'
ModelBase = require '../../mvc/model'
OjsonSocket = require '../../socket/ojson_socket'
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

    sock = new OjsonSocket io.connect '/'
    cookies = new Cookies sock, manifest['cookies']
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

    @['manifest'] = @manifest = manifest
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

    # In principle, you want to route only the server URI first, then route
    # everything so the bootstrapping is done on the server-visible parts of
    # the URL. This is done by first routing
    #      # route only the URL the server saw when it rendered (to bootstrap)
    #      router.route canonicalUri || navigate.uri.clone().setHash('')
    # then building everything then routing
    #      router.useNavigate canonicalUri
    # However, since the client-side details (1) shouldn't conflict with
    # server-side rendering and (2) should generally pertain to scrolling,
    # etc., it should be fine to route the full route up front

    router.useNavigate canonicalUri

    Template.bootRoot = $container
    (new Controller['body'] this, $inWindow: true)['appendTo'] $container
    @['booting'] = false
    Template.bootRoot = null
    Model.clearQueryCache()
    delete Template.bootstrapRoot
    debug "DONE WITH EVENT LOOP"

    # now -- after everything has booted using only local models -- we can start receiving socket updates
    Model.attachSocketHandlers this


