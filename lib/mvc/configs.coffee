buildClasses = require './build_classes'

module.exports = class Configs
  constructor: ->
    @configs = Object.create null
    @mixins = Object.create null

  add: (type, config={}) ->
    if typeof config is 'function'
      @mixins[type] && throw new Error("already added #{type}")
      @mixins[type] = config
    else
      @configs[type] && throw new Error("already added #{type}")
      @configs[type] = config
    return

  _applyMixin: (config, mixin) ->
    if Array.isArray mixin
      @_applyMixin config, m for m in mixin

    else if typeof mixin is 'string'
      @mixins[mixin](config)

    else if mixin?
      for type, args of mixin
        if Array.isArray args
          @mixins[type](config, args...)
        else
          @mixins[type](config, args)

    return

  applyMixins: ->
    for type, config of @configs when mixin = config['mixins'] || config['mixin']
      @_applyMixin config, mixin
      delete config['mixins']
    return

  buildClasses: (base) ->
    buildClasses @configs, base
