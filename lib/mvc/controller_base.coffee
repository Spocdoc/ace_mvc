debugCascade = global.debug 'ace:cascade'
debugMVC = global.debug 'ace:mvc'
clone = require '../utils/clone'

reserved = ['constructor','static','view','outlets','outletMethods','template','inWindow']

module.exports = (pkg) ->
  cascade = pkg.cascade
  mvc = pkg.mvc

  mvc.ControllerBase = class ControllerBase extends mvc.Global
    constructor: ->
      _this = this

      @vars = (if @_name then @_parent.vars[@_name] else @_parent.vars) || {}

      @Outlet = class Outlet extends @Outlet
        constructor: (func, debug) ->
          super func, context: _this, auto: true
          debugCascade "created outlet for #{debug}: #{this}"

      @outlets = {}

    'depute': (method, args...) ->
      deputy = @outlets['deputy']?.get() || @_parent
      if fn = deputy[method]
        fn.apply(deputy, args)
      else if fn = deputy['depute']
        fn.apply(deputy, arguments)

    toString: ->
      "#{@constructor.name} [#{@_type}] name [#{@_name}]"

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
              args = arguments
              cascade.Cascade.Block =>
                method.apply this, args
              return
      return

    _applyConstructors: (config, settings) ->
      constructors = config['constructor']

      if Array.isArray constructors
        for constructor in constructors
          constructor.call this, settings
      else
        constructors.call this, settings

      return

    _buildOutlet: (name) ->
      @[name] = @outlets[name] = @vars[name]?.outlet || new @Outlet

    _buildOutlets: ->
      @_buildOutlet name for name of @constructor._outletDefaults
      return

    _setOutlets: (settings) ->
      for k,v of @constructor._outletDefaults
        o = @outlets[k]

        if typeof v is 'function'
          o.context = this
          o.set v
        else unless @vars[k]?.outlet # i.e., can't set an outlet that's a routing var via defaults
          o.set(if settings.hasOwnProperty k then settings[k] else v)
      return
