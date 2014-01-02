buildClasses = require './build_classes'
debugError = global.debug 'error'

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

  merge: (into, from) ->
    for k, v of from
      if current = into[k]
        if Array.isArray current
          if Array.isArray v
            current.push v...
          else
            current.push v
        else
          into[k] = [current].concat v
      else
        into[k] = v
    return

  _applyMixin: (config, spec) ->
    if Array.isArray spec
      @_applyMixin config, m for m in spec

    else if typeof spec is 'string'
      if mixin = @mixins[spec]
        mixin(config)
      else if otherConfig = @configs[spec]
        @merge config, otherConfig

    else if spec?
      for type, args of spec
        if mixin = @mixins[type]
          if Array.isArray args
            mixin(config, args...)
          else
            mixin(config, args)
        else
          debugError "Can't find mixin #{type}"

    return

  applyMixins: ->
    for type, config of @configs when spec = config['mixins']
      @_applyMixin config, spec
      delete config['mixins']
    return

  buildClasses: (base) ->
    buildClasses @configs, base
