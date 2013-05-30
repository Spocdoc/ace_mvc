ControllerBase = require './controller_base'
View = require './view'
Model = require './model'
{defaults} = require '../mixin'

class Controller extends ControllerBase
  @_super = @__super__.constructor

  class @Config extends @_super.Config
    @_super = @__super__.constructor

    @defaultConfig = defaults {}, @_super.defaultConfig,
      view: ''

  @defaultOutlets = @_super.defaultOutlets.concat ['view','model']

  appendTo: ($container) -> @view.appendTo($container)
  prependTo: ($container) -> @view.prependTo($container)
  insertBefore: ($elem) -> @view.insertBefore($elem)
  insertAfter: ($elem) -> @view.insertAfter($elem)
  remove: -> @view.remove()

  _buildView: (arg, settings) ->
    outlet = @outlets['view'] ||= @newOutlet('view')

    if arg instanceof View
      outlet.set @view = arg
    else if typeof arg is 'string'
      outlet.set @view = @newView arg
    else
      break for k,v of arg
      outlet.set @view = @newView k, undefined, v

    @$ = {}
    for k, v of @view.outlets
      @$[k] = v
      @["$#{k}"] = v

    # view outlet is immutable
    outlet.set = ->

  _buildMethod: (k, m) ->
    if k[0] is '$'
      if typeof m is 'function'
        @outletMethods.push m = @newOutletMethod(m, k)
      @view[k[1..]].set m
    else if @outlets[k]
      if m.length
        @_outletDefaults[k] = (done) => m.call(this,done)
      else
        @_outletDefaults[k] = => m.call(this)
    else
      @[k] = m

  _build: (base, settings) ->
    base = base.get(this)
    config = base.config

    @_buildMixins config.mixins, settings?.mixins
    @_buildOutlets config.outlets
    @_buildOutletMethods config.outletMethods

    unless @_mixing
      @_buildView settings?.view || config.view || base.name, settings

    @_buildMethods config
    @_buildMethods config['methods']

    unless @_mixing
      @_setOutlets settings

    base

  newView: (type, name, settings) -> new View(type, this, name, settings)
  newModel: (type, idOrSpec) -> new Model(type, idOrSpec)
  newController: (type, name, settings) -> new Controller(type, this, name, settings)

module.exports = Controller
