Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
OutletMethod = require '../cascade/outlet_method'
Template = require './template'
require '../polyfill'

class ViewBase
  constructor: (@name, set) ->
    @config = {}
    @config.set = (obj) => @set(obj)
    if typeof set is 'function'
      @func = set
    else
      @set set if set

  set: (obj) ->
    @config[k] = v for k,v of obj when k isnt 'set'

  get: (view, args=[]) ->
    return this unless @func
    vb = new @constructor @name
    @func.apply(view, [vb.config].concat(args))
    vb

  @reserved: {
    mixins: 1
    outlets: 1
    statlets: 1
    outletMethods: 1
    template: 1
  }

class View
  count = 0
  uniqueId = ->
    "#{++count}-View"

  @add: (name, fnOrHash) ->
    throw new Error("View: already added #{name}") if @[name]?
    base = ViewBase[name] = new ViewBase name, fnOrHash
    @[name] = (parent, name, settings) ->
      obj = new @(parent, name, settings)
      obj._build(base, settings)
      obj
    return this

  @defaultOutlets = ['template','inWindow']

  constructor: (@parent, @name, settings) ->
    @path = @parent.path.concat(@name)
    @outlets = []
    @outletMethods = []

  appendTo: ($container) ->
    @remove()
    @$container = $container
    $container.append(@$root)
    if other = $container.template?.view.inWindow
      @inWindow.set(other)
    else
      @inWindow.set(true)

  remove: ->
    return unless @$container
    @$root.remove()
    @inWindow.detach()
    @inWindow.set(false)

  _buildOutlet: (outlet) ->
    if typeof outlet isnt 'string'
      @[n] = @outlets[n] = new @_Outlet(n,d) for n,d of outlet
    else
      @[outlet] = @outlets[outlet] = new @_Outlet(outlet) unless @[outlet]
    return

  _buildOutlets: (outlets) ->
    return unless outlets

    @[k] ||= @outlets[k] = new @_Outlet(k) for k in @constructor.defaultOutlets

    if Array.isArray outlets
      @_buildOutlet k for k in outlets
    else
      @_buildOutlet outlets
    return

  _buildStatelets: (statelets) ->
    return unless statelets
    if @_Statelet
      @[k] = @outlets[k] = new @_Statelet(k) for k in statelets
    else
      @_buildOutlets statelets
    return

  _buildMethod: do ->
    iom = []

    addOutflows = (view, outlet, arr) ->
      for m in arr
        outlet.outflows.add (iom[m.cid ?= uniqueId()] ||= => m.call(view))
      return

    addStringOutflow = (view, name, str, outlet) ->
      e = view.$[name]
      outflows = outlet.outflows

      switch str
        when 'toggleClass'
          outflows.add ->
            e[str].call(e, name, outlet.get())

        when 'text','html'
          outflows.add ->
            if view.domCache[name] isnt (v = outlet.get())
              view.domCache[name] = v
              e[str].call(e, v)

        else
          outflows.add ->
            e[str].call(e, outlet.get())

      return

    setDom = (view, name, obj) ->
      for k, v of obj
        view.outletMethods.push om = new view._OutletMethod v
        addStringOutflow(view, name, k, om)
      return

    (k,m) ->
      k = k[1..] if k[0] is '$'

      if typeof m is 'object' and !Array.isArray(m)
        setDom(this, k, m)

      else if (outlet = @outlets[k])?
        switch typeof m
          when 'string' then addStringOutflow this, k, m, outlet
          when 'function'
            if m.length > 0
              @outletMethods.push om = new @_OutletMethod m
              om.outflows.add -> outlet.set(om.get())
            else
              addOutflows(this, outlet, [m])
          else
            addOutflows(this, outlet, m)
      else
        @[k] = m

      return

  _buildMethods: (config) ->
    for k,m of config when !ViewBase.reserved[k]
      if Array.isArray m
        @_buildMethod k, n for n in m
      else
        @_buildMethod k, m
    return

  _buildOutletMethods: (arr) ->
    for m in arr
      @outletMethods.push new @_OutletMethod m
    return

  _buildTemplate: (arg) ->
    template = @outlets['template'] = new @_Outlet('template')
    template.view = this
    template.outflows.add =>
      @domCache = {}
      delete @[k] for k of @ when k[0] is '$'
      @[k] = v for k,v of template.get() when k[0] is '$'
      return

    if arg instanceof Template
      template.set arg
    else
      template.set new @_Template arg
    return

  _buildMixins: (mixins) ->
    if typeof mixins is 'string'
      @_build ViewBase[mixins]
    else if Array.isArray(mixins)
      @_buildMixins elem for elem in mixins
    else
      for name,args of mixins
        @_build ViewBase[name].get(this, args)
    return

  _build: (base, settings) ->
    base = base.get(this)
    config = base.config

    @_buildMixins config.mixins
    @_buildOutlets config.outlets
    @_buildOutletMethods config.outletMethods
    @_buildStatelets config.statelets
    @_buildMethods config

    Cascade.Block =>
      @outlets[k].set(v) for k,v of settings when !ViewBase.reserved[k]
      @outlets['template'].get() || @_buildTemplate settings.template || config.template || base.name

    return

  _Template: (name) -> new Template[name](this)
  _Outlet: (name, init) -> new Outlet(init)
  _OutletMethod: (func) ->
    new OutletMethod func, @outlets, silent: true, context: this

module.exports = View
