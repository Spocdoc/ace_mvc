Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
{extend} = require '../mixin'
clone = require '../clone'
debugCascade = global.debug 'ace:cascade'
debugMVC = global.debug 'ace:mvc'

class ControllerBase
  class @Config
    @defaultConfig =
      mixins: []
      outlets: []
      outletMethods: []
      extend: (obj) ->
        for k,v of obj
          unless (current = @[k])?
            @[k] = v
          else
            current = [current] unless Array.isArray current
            if Array.isArray v
              Array.prototype.push.apply(current, v)
            else
              current.push v
        return


    constructor: (@type, config) ->
      if typeof config is 'function'
        @func = config
      else
        @config = clone @constructor.defaultConfig
        extend @config, config

    get: (controllerBase, args=[]) ->
      return this unless @func
      vb = new @constructor @type
      @func.apply(controllerBase, [vb.config].concat(args))
      vb

  @add: (type, fnOrHash) ->
    throw new Error("#{@name}: already added #{type}") if @Config[type]?
    @Config[type] = new @Config type, fnOrHash
    return this

  @defaultOutlets = [ 'delegate' ]

  constructor: (@_type, @_parent, @_name, settings) ->
    prev = Outlet.auto; Outlet.auto = null
    debugMVC "Building #{@}"
    @_path = @_parent._path
    @_path = @_path.concat(@_name) if @_name
    @outlets = {}
    @outletMethods = []
    Cascade.Block =>
      @_build(@constructor.Config[@_type], settings)
    debugMVC "done building #{@}"
    Outlet.auto = prev

  'delegate': (method, args...) ->
    return unless delegate = @outlets['delegate'].get()
    if fn = delegate[method]
      fn.apply(delegate, args)
    else if fn = delegate['delegate']
      fn.apply(delegate, arguments)

  toString: ->
    "#{@constructor.name} [#{@_type}] name [#{@_name}]"

  _buildOutlet: (outlet) ->
    if typeof outlet isnt 'string'
      for k,v of outlet
        if v instanceof Cascade
          o = v
        else
          @_outletDefaults[k] = v
          o = @to k
        @[k] = @outlets[k] = o
    else
      @[outlet] = @outlets[outlet] = @to(outlet) unless @[outlet]
    return

  _buildOutlets: (outlets) ->
    return unless outlets
    @_outletDefaults = {}

    @outlets[k] ?= @[k] = @to(k) for k in @constructor.defaultOutlets

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
      @outlets[k].set(v) if @outlets[k].get() is undefined or typeof v is 'function'

    # special case of "delegate" outlet defaulting to _parent
    @outlets['delegate'].set(@_parent) unless @outlets['delegate'].get() or @_parent._nodelegate
    delete @['delegate']

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
      for type,args of mixins
        mixin = @constructor.Config[type]
        throw new Error("No such mixin: [#{type}]") unless mixin
        @_build mixin.get(this, args)

    @_buildMixins mixins2 if mixins2

    --@_mixing
    return

module.exports = ControllerBase

