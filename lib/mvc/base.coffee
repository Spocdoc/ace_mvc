debug = global.debug 'ace:mvc'
clone = require '../utils/clone'
Outlet = require '../utils/outlet'

reserved = ['constructor','static','view','outlets','outletMethods','template','inWindow']

module.exports = class Base
  @add: (type, config) ->
    if config? and typeof config is 'object' and !Array.isArray constructor = config['constructor']
      config['constructor'] = if constructor then [constructor] else []
    @configs.add type, config
    return this

  @finish: ->
    @configs.applyMixins()
    @[type] = clazz for type, clazz of @configs.buildClasses this
    return

  constructor: ->
    @vars = (if @aceName then @aceParent.vars[@aceName] else @aceParent.vars) || {}
    @[k] = v for k,v of @globals = @aceParent.globals

    @outlets = {}

    # public
    @['aceParent'] = @aceParent
    @['aceName'] = @aceName

  'depute': (method, args...) ->
    deputy = @outlets['deputy']?.get() || @aceParent
    if fn = deputy[method]
      fn.apply(deputy, args)
    else if fn = deputy['depute']
      fn.apply(deputy, arguments)

  varPrefix: ''

  _runConstructors: (settings) ->
    if Array.isArray constructors = @aceConfig['constructor']
      for constructor in constructors
        constructor.call this, settings
    return

  _buildOutlet: (name) ->
    @[name] = @outlets[name] = @vars["#{@varPrefix}#{name}"]?.outlet || new Outlet undefined, this, true

  _buildOutlets: ->
    @_buildOutlet name for name of @constructor._outletDefaults
    return

  _setOutlets: (settings) ->
    for k,v of @constructor._outletDefaults
      if (o = @outlets[k]).value is undefined
        if typeof v is 'function'
          o.context = this
          o.set v
        else unless @vars["#{@varPrefix}#{k}"]?.outlet # i.e., can't set an outlet that's a routing var via defaults
          o.set(if settings.hasOwnProperty k then settings[k] else v)
    return
