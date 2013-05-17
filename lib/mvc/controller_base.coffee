Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
OutletMethod = require '../cascade/outlet_method'

class ControllerBase

  class @Config
    @defaultConfig =
      mixins: []
      outlets: []
      outletMethods: []

    constructor: (@name, config) ->
      @config = @constructor.defaultConfig

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
    base = @Config[name] = new @Config name, fnOrHash
    @[name] = (parent, name, settings) ->
      obj = new @(parent, name, settings)
      Cascade.Block ->
        obj._build(base, settings)
      obj
    return this

  @defaultOutlets = []

  constructor: (@parent, @name, settings) ->
    @path = @parent.path
    @path = @path.concat(@name) if @name
    @outlets = []
    @outletMethods = []

  _buildOutlet: (outlet) ->
    if typeof outlet isnt 'string'
      for k,v of outlet
        if v instanceof Cascade
          o = v
        else
          @_outletDefaults[k] = v
          o = new @_Outlet k
        @[k] = @outlets[k] = o
    else
      @[outlet] = @outlets[outlet] = new @_Outlet(outlet) unless @[outlet]
    return

  _buildOutlets: (outlets) ->
    return unless outlets
    @_outletDefaults = {}

    @[k] ||= @outlets[k] = new @_Outlet(k) for k in @constructor.defaultOutlets

    if Array.isArray outlets
      @_buildOutlet k for k in outlets
    else
      @_buildOutlet outlets
    return

  _setOutlets: (settings) ->
    for k,v of settings when !Config.defaultConfig[k]
      delete @_outletDefaults[k]
      @outlets[k]?.set(v)

    for k,v of @_outletDefaults
      @outlets[k].set(v) if @outlets[k].get() is undefined

  _buildMethods: (config) ->
    for k,m of config when !Config.defaultConfig[k]
      if Array.isArray m
        @_buildMethod k, n for n in m
      else
        @_buildMethod k, m
    return

  _buildOutletMethods: (arr) ->
    for m in arr
      @outletMethods.push new @_OutletMethod m
    return

  _buildMixins: (mixins) ->
    @_mixing ||= 0
    ++@_mixing

    if typeof mixins is 'string'
      @_build Config[mixins]
    else if Array.isArray(mixins)
      @_buildMixins elem for elem in mixins
    else
      for name,args of mixins
        @_build Config[name].get(this, args)

    --@_mixing
    return

  _build: (base, settings) ->
    base = base.get(this)
    config = base.config

    @_buildMixins config.mixins
    @_buildOutlets config.outlets
    @_buildOutletMethods config.outletMethods
    @_buildMethods config

    unless @_mixing
      @_setOutlets settings

    base

  _Outlet: (name) -> new Outlet
  _OutletMethod: (func) ->
    new OutletMethod func, @outlets, silent: true, context: this

module.exports = ControllerBase
