ControllerBase = require './controller_base'
View = require './view'
Model = require './model'
{defaults} = require '../mixin'

class Controller extends ControllerBase
  @_super = @__super__.constructor

  class @Config extends @_super.ConfigBase
    @_super = @__super__.constructor

    @defaultConfig = defaults {}, @_super.defaultConfig,
      view: ''
      model: ''

  @defaultOutlets = @_super.defaultOutlets.concat ['view','model']

  appendTo: ($container) -> @view.appendTo($container)
  remove: -> @view.remove()

  _buildView: (arg, settings) ->
    outlet = @outlets['view'] ||= new @Outlet('view')

    if arg instanceof View
      outlet.set @view = arg
    else if typeof arg is 'string'
      outlet.set @view = new @View arg
    else
      break for k,v of arg
      outlet.set @view = new @View k, undefined, v

    @$ = {}
    for k, v of @view.outlets
      @$[k] = v
      @["$#{k}"] = v

    # view outlet is immutable
    outlet.set = ->

  _buildMethod: (k, m) ->
    if k[0] is '$'
      @outletMethods.push om = new @OutletMethod m
      vo = @view.get()[k[1..]]
      om.outflows.add => vo.set(om.get())
    else
      @[k] = m

  _build: (base, settings) ->
    base = base.get(this)
    config = base.config

    @_buildMixins config.mixins, settings?.mixins
    @_buildOutlets config.outlets
    @_buildOutletMethods config.outletMethods

    unless @_mixing
      @_buildView settings.view || config.view || base.name, settings

    @_buildMethods config

    unless @_mixing
      @_setOutlets settings

    base

  View: (type, name, settings) -> new View[type](this, name, settings)
  Model: (type, idOrSpec) -> new Model[type](idOrSpec)

module.exports = Controller
