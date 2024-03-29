debug = global.debug 'ace:mvc'
clone = require 'diff-fork/clone'
Outlet = require 'outlet'

reserved = ['deputy','constructor','static','view','outlets','outletMethods','template','inWindow']

module.exports = class Base
  @add: (type, config) ->
    if config? and typeof config is 'object' and !Array.isArray constructor = config['constructor']
      config['constructor'] = if config.hasOwnProperty('constructor') then [constructor] else []
    @configs.add type, config
    return this

  @compile: ->
    @configs.applyMixins()
    @[type] = clazz for type, clazz of @configs.buildClasses this
    return

  constructor: ->
    @vars = (if @aceName then @aceParent.vars[@aceName] else @aceParent.vars) || {}
    @[k] = v for k,v of @globals = @aceParent.globals

    @['outlets'] = @outlets = {}
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
    @_buildOutlet name for name of @constructor.outletDefaults
    return

  _setOutletsFromDefaults: (defaults, settings) ->
    for k,v of defaults
      if settings and settings.hasOwnProperty k
        v = settings[k]
      else if @_outletDefaults and @_outletDefaults.hasOwnProperty k
        v = @_outletDefaults[k]

      if (o = @outlets[k]).value isnt undefined
        if typeof v is 'function'
          o.initProxy v, this
      else
        if typeof v is 'function'
          o.context = this
          o.set v
        else unless @vars["#{@varPrefix}#{k}"]?.outlet # i.e., can't set an outlet that's a routing var via defaults
          o.set v unless v is undefined

      delete @_outletDefaults[k] if @_outletDefaults
    return

  _setOutlets: (settings) ->
    @_setOutletsFromDefaults @constructor.outletDefaults, settings
    @_setOutletsFromDefaults @_outletDefaults, settings if @_outletDefaults
    delete @_outletDefaults
    return

  'addOutlet': (name, value) ->
    @_buildOutlet name
    (@_outletDefaults ||= {})[name] = value
    return

