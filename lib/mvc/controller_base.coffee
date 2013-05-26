Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
OutletMethod = require '../cascade/outlet_method'
{extend} = require '../mixin'
clone = require '../clone'

class ControllerBase
  class @Config
    @defaultConfig =
      mixins: []
      outlets: []
      outletMethods: []

    constructor: (@name, config) ->
      @config = clone @constructor.defaultConfig

      if typeof config is 'function'
        @func = config
      else
        extend @config, config

    get: (controllerBase, args=[]) ->
      return this unless @func
      vb = new @constructor @name
      @func.apply(controllerBase, [vb.config].concat(args))
      vb

  @add: (name, fnOrHash) ->
    throw new Error("#{@name}: already added #{name}") if @[name]?
    @Config[name] = new @Config name, fnOrHash
    return this

  @defaultOutlets = []

  constructor: (@type, @parent, @name, settings) ->
    Outlet.enterContext()
    try
      @path = @parent.path
      @path = @path.concat(@name) if @name
      @outlets = {}
      @outletMethods = []
      Cascade.Block =>
        @_build(@constructor.Config[@type], settings)
    finally
      Outlet.exitContext()

  _buildOutlet: (outlet) ->
    if typeof outlet isnt 'string'
      for k,v of outlet
        if v instanceof Cascade
          o = v
        else
          @_outletDefaults[k] = v
          o = @newOutlet k
        @[k] = @outlets[k] = o
    else
      @[outlet] = @outlets[outlet] = @newOutlet(outlet) unless @[outlet]
    return

  _buildOutlets: (outlets) ->
    return unless outlets
    @_outletDefaults = {}

    @[k] ?= @outlets[k] = @newOutlet(k) for k in @constructor.defaultOutlets

    if Array.isArray outlets
      @_buildOutlet k for k in outlets
    else
      @_buildOutlet outlets
    return

  _setOutlets: (settings) ->
    for k,v of settings when !@constructor.Config.defaultConfig[k]?
      delete @_outletDefaults[k]
      @outlets[k]?.set(v)

    for k,v of @_outletDefaults
      @outlets[k].set(v) if @outlets[k].get() is undefined

  _buildMethods: (config) ->
    for k,m of config when !@constructor.Config.defaultConfig[k]?
      if Array.isArray m
        @_buildMethod k, n for n in m
      else
        @_buildMethod k, m
    return

  _buildOutletMethods: (arr) ->
    for m in arr
      @outletMethods.push @newOutletMethod m
    return

  _buildMixins: (mixins, mixins2) ->
    @_mixing ||= 0
    ++@_mixing

    if typeof mixins is 'string'
      @_build @constructor.Config[mixins]
    else if Array.isArray(mixins)
      @_buildMixins elem for elem in mixins
    else
      for name,args of mixins
        @_build @constructor.Config[name].get(this, args)

    @_buildMixins mixins2 if mixins2

    --@_mixing
    return

  newOutlet: (name) -> new Outlet
  newOutletMethod: (func) ->
    new OutletMethod func, @outlets, silent: !!func.length, context: this

module.exports = ControllerBase

