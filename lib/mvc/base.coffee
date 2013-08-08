debug = global.debug 'ace:mvc'
clone = require '../utils/clone'
Outlet = require '../utils/outlet'

reserved = ['constructor','static','view','outlets','outletMethods','template','inWindow']

module.exports = class Base
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

  @_applyOutlet: (outlet) ->
    if typeof outlet isnt 'string'
      @_outletDefaults[k] = v for k,v of outlet
    else
      @_outletDefaults[outlet] = undefined
    return

  @_applyOutlets: (config) ->
    @_outletDefaults = {}

    if outlets = config['outlets']
      if Array.isArray outlets
        @_applyOutlet k for k in outlets
      else
        @_applyOutlet outlets

    if outletMethods = config['outletMethods']
      @_outletDefaults["_#{i}"] = m for m,i in outletMethods

  @_applyStatic: (config) ->
    @[name] = fn for name, fn of config['static']
    return

  @_applyMethods: (config) ->
    for name, method of config when name.charAt(0) isnt '$' and not (name in reserved)
      if @_outletDefaults.hasOwnProperty name
        @_outletDefaults[name] = method
      else
        do (method) =>
          @prototype[name] = ->
            Outlet.openBlock()
            try
              method.apply this, arguments
            finally
              Outlet.closeBlock()
    return

  _applyConstructors: (settings) ->
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
