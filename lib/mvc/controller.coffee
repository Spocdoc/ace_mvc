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

  _buildView: (view, settings) ->


  _build: (base, settings) ->
    base = super
    config = base.config

    @_buildView settings.view || config.view || base.name, settings

    return

  _View: (type, name, config) -> new View[type](this, name, config)
  _Model: (type, idOrSpec) -> new Model[type](idOrSpec)

module.exports = Controller
