ControllerBase = require './controller_base'
Cascade = require '../cascade/cascade'
View = require './view'
Model = require './model'
{defaults} = require '../mixin'

class Controller extends ControllerBase
  @name = 'Controller'
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
    outlet = @outlets['view'] ||= @to('view')

    if arg instanceof View
      outlet.set @view = arg
    else if typeof arg is 'string'
      outlet.set @view = @newView arg
    else
      break for k,v of arg
      outlet.set @view = @newView k, undefined, v

    @$ = {}
    for k, v of @view.outlets
      @outlets["$#{k}"] = @["$#{k}"] = @$[k] = v

    # view outlet is immutable
    outlet.set = ->

  _buildMethod: (k, m) ->
    if k.charAt(0) is '$'
      if typeof m is 'function'
        @outletMethods.push m = @newOutletMethod(m, k)
      @view.outlets[k.substr(1)].set m
    else if @outlets[k]
      if m.length
        @_outletDefaults[k] = (done) => m.call(this,done)
      else
        @_outletDefaults[k] = => m.call(this)
    else
      @[k] = (args...) =>
        Cascade.Block =>
          m.apply this, args

  _build: (base, settings) ->
    base = base.get(this)
    config = base.config

    @_buildMixins config.mixins, settings?.mixins
    @_buildOutlets config.outlets

    unless @_mixing
      @_buildView settings?.view || config.view || base.type, settings

    @_buildOutletMethods config.outletMethods
    @_buildMethods config
    @_buildMethods config['methods']

    unless @_mixing
      @_setOutlets settings

    base

module.exports = Controller
