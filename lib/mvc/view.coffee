ControllerBase = require './controller_base'
Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
OutletMethod = require '../cascade/outlet_method'
Template = require './template'
{defaults} = require '../mixin'
require '../polyfill'
debugDom = global.debug 'ace:dom'

class View extends ControllerBase
  @_super = @__super__.constructor

  class @Config extends @_super.Config
    @_super = @__super__.constructor

    @defaultConfig = defaults {}, @_super.defaultConfig,
      statelets: []
      template: ''

  @defaultOutlets = @_super.defaultOutlets.concat ['template','inWindow']

  appendTo: Outlet.noAuto ($container) ->
    @remove()
    @$container = $container
    $container.append(@$root)

    if other = $container.template?.view?.inWindow
      @inWindow.set(other)
      return

    for parent in $container.parents()
      if other = parent.template?.view?.inWindow
        @inWindow.set(other)
        return

    @inWindow.set(true)
    return

  remove: Outlet.noAuto ->
    return unless @$container
    @inWindow.detach()
    @inWindow.set(false)
    @$root.remove()
    return

  _buildMethod: do ->
    addStringOutflow = (view, name, str, outlet) ->
      e = view.$[name]
      outflows = outlet.outflows

      switch str
        when 'toggleClass'
          outflows.add ->
            debugDom "calling #{str} in dom on #{name}"
            e[str].call(e, name, outlet.get())

        when 'text','html'
          outflows.add ->
            if view.domCache[name] isnt (v = outlet.get())
              view.domCache[name] = v
              debugDom "calling #{str} in dom on #{name}"
              e[str].call(e, v)

        else
          outflows.add ->
            debugDom "calling #{str} in dom on #{name}"
            e[str].call(e, outlet.get())

      return

    setDom = (view, name, obj) ->
      for k, v of obj
        view.outletMethods.push om = view.newOutletMethod(v, k)
        addStringOutflow(view, name, k, om)
      return

    (k,m) ->
      s = if k[0] is '$' then k[1..] else k

      if k[0] is '$' and typeof m is 'object'
        setDom(this, s, m)

      else if (outlet = @outlets[s])?
        switch typeof m
          when 'string'
            addStringOutflow this, s, m, outlet
          when 'function'
            @outletMethods.push om = @newOutletMethod(m,k)
            outlet.set om
      else
        @[s] = m

      return

  _buildTemplate: (arg) ->
    outlet = @outlets['template'] ||= @newOutlet('template')

    if arg instanceof Template
      outlet.set @template = arg
    else
      outlet.set @template = @newTemplate arg

    @template.view = this
    @domCache = {}
    @$ = @template.$
    @[k] = v for k,v of @template when k[0] is '$'

    # disallow changing the template
    outlet.set = ->

    return

  _buildStatelets: (statelets) ->
    return unless statelets
    @_stateletDefaults ||= {}
    for k,v of statelets
      @_stateletDefaults[k] = v
      @[k] = @outlets[k] = @newStatelet(k)
    return

  _setStatelet: (k, v) ->
    if typeof v is 'function'
      v = v() unless v.length
    @outlets[k]?.set(v)
    return

  _setStatelets: (settings) ->
    for k,v of settings when !@constructor.Config.defaultConfig[k]?
      @_setStatelet k, v
    for k,v of @_stateletDefaults
      @_setStatelet k, v
    return

  _build: (base, settings) ->
    base = base.get(this)
    config = base.config

    @_buildMixins config.mixins, settings?.mixins
    @_buildOutlets config.outlets
    @_buildStatelets config.statelets
    @_buildOutletMethods config.outletMethods

    unless @_mixing
      @_buildTemplate settings?.template || config.template || base.name

    @_buildMethods config

    unless @_mixing
      @_setOutlets settings
      @_setStatelets settings

    base

  newTemplate: (type) -> new Template(type, this)

module.exports = View
