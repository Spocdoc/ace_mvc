ControllerBase = require './controller_base'
ConfigBase = require './config_base'
Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'
OutletMethod = require '../cascade/outlet_method'
Template = require './template'
{defaults} = require '../mixin'
require '../polyfill'

class View extends ControllerBase
  @_super = @__super__.constructor

  class @Config extends @_super.ConfigBase
    @_super = @__super__.constructor

    @defaultConfig = defaults {}, @_super.defaultConfig,
      statelets: []
      template: ''

  @defaultOutlets = @_super.defaultOutlets.concat ['template','inWindow']

  appendTo: ($container) ->
    @remove()
    @$container = $container
    $container.append(@$root)
    loop
      if other = $container.template?.view?.inWindow
        @inWindow.set(other)
        return
      break unless ($container = $container.parent()).length
    @inWindow.set(true)
    return

  remove: ->
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
      s = if k[0] is '$' then k[1..] else k

      if k[0] is '$' and typeof m is 'object'
        setDom(this, s, m)

      else if (outlet = @outlets[s])?
        switch typeof m
          when 'string' then addStringOutflow this, s, m, outlet
          when 'function'
            @outletMethods.push om = new @OutletMethod m
            om.outflows.add -> outlet.set(om.get())
      else
        @[s] = m

      return

  _buildTemplate: (arg) ->
    outlet = @outlets['template'] ||= new @Outlet('template')

    if arg instanceof Template
      outlet.set @template = arg
    else
      outlet.set @template = new @Template arg

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
      @[k] = @outlets[k] = new @Statelet(k)
    return

  _setStatelet: (k, v) ->
    if typeof v is 'function'
      v = v() unless v.length
    @outlets[k]?.set(v)
    return

  _setStatelets: (settings) ->
    for k,v of settings when !Config.defaultConfig[k]
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
      @_buildTemplate settings.template || config.template || base.name

    @_buildMethods config

    unless @_mixing
      @_setOutlets settings
      @_setStatelets settings

    base

  Template: (name) -> new Template[name](this)

module.exports = View
