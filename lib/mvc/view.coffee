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

  insertAfter: ($elem) ->
    @remove()
    $container = $elem.parent()
    debugDom "insert #{@} after #{$elem}"
    @$container = $container
    $elem.after(@$root)
    @_setInWindow $container

  insertBefore: ($elem) ->
    @remove()
    $container = $elem.parent()
    debugDom "insert #{@} before #{$elem}"
    @$container = $container
    $elem.before(@$root)
    @_setInWindow $container

  prependTo: ($container) ->
    @remove()
    debugDom "prepend #{@} to #{$container}"
    @$container = $container
    $container.prepend(@$root)
    @_setInWindow $container

  appendTo: ($container) ->
    @remove()
    debugDom "append #{@} to #{$container}"
    @$container = $container
    $container.append(@$root)
    @_setInWindow $container

  _setInWindow: ($container) ->
    if other = $container.template?.view?.inWindow
    else
      for parent in $container.parents()
        (break) if other = parent.template?.view?.inWindow

    @inWindow.set(other || true)
    return

  remove: ->
    return unless @$container
    debugDom "remove #{@} from #{@$container}"
    @$container = undefined
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
            debugDom "calling #{str} in dom on #{name} with #{outlet.get()}"
            e[str].call(e, name, outlet.get())

        when 'text','html'
          outflows.add ->
            if view.domCache[name] isnt (v = outlet.get())
              view.domCache[name] = v
              debugDom "calling #{str} in dom on #{name} with #{v}"
              e[str].call(e, v)

        else
          outflows.add ->
            debugDom "calling #{str} in dom on #{name} with #{outlet.get()}"
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
    @$root = @template.$root # closure mangling

    # disallow changing the template
    outlet.set = ->

    return

  _buildStatelet: (statelet) ->
    unless typeof statelet is 'string'
      for k,v of statelet
        if v instanceof Cascade
          o = v
        else
          @_stateletDefaults[k] = v
          o = @newStatelet k
        @[k] ||= @outlets[k] = o
    else
      @[statelet] ||= @outlets[statelet] = @newStatelet(statelet)
    return

  _buildStatelets: (statelets) ->
    return unless statelets
    @_stateletDefaults ||= {}

    if Array.isArray statelets
      @_buildStatelet k for k in statelets
    else
      @_buildStatelet statelets
    return

  _setStatelet: (k, v) ->
    if typeof v is 'function'
      v = v.call(this) unless v.length
    @outlets[k]?.runner.getset = v
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
    @_buildMethods config['methods']

    unless @_mixing
      @_setOutlets settings
      @_setStatelets settings

    base

  newTemplate: (type) -> new Template(type, this)

module.exports = View
