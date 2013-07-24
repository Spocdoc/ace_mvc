Base = require './base'
View = require './view'
debugCascade = global.debug 'ace:cascade'
debugMvc = global.debug 'ace:mvc'

configs = new (require('./configs'))

module.exports = class Controller extends Base
  @name = 'Controller'

  @add: (type, config) -> configs.add type, config

  @finish: ->
    configs.applyMixins()

    ControllerBase = Controller
    types = {}
    for type,config of configs.configs
      types[type] = class Controller extends ControllerBase
        _type: type
        _config: config

        @_applyStatic config
        @_applyOutlets config
        @_applyMethods config
    ControllerBase[k] = v for k, v of types
    return

  constructor: (@_parent, @_name, settings={}) ->
    debugMvc "Building #{@}"

    super()

    Outlet.openBlock()
    prev = Outlet.auto; Outlet.auto = null
    try
      @_buildOutlets()
      @_buildView settings['view'] || @_config['view'] || type, settings
      @_buildDollar()
      @_applyConstructors settings
      @_setOutlets settings
    finally
      Outlet.auto = prev
      Outlet.closeBlock()

    debugMvc "done building #{@}"


  'appendTo': ($container) -> @['view']['appendTo']($container)
  'prependTo': ($container) -> @['view']['prependTo']($container)
  'insertBefore': ($elem) -> @['view']['insertBefore']($elem)
  'insertAfter': ($elem) -> @['view']['insertAfter']($elem)
  'remove': -> @['view']['remove']()

  _buildView: (arg, settings) ->
    if arg instanceof View
      @['view'] = arg
    else if typeof arg is 'string'
      @['view'] = new View[arg] this
    else
      break for k,v of arg
      outlet.set @['view'] = new View[k] this, undefined, v

    @$ = {}
    @outlets["$#{k}"] = @["$#{k}"] = @$[k] = v for k, v of @['view'].outlets
    return

  _buildDollar: ->
    for k,v of @_config when k.charAt(0) is '$'
      v = new Outlet v, this, true if typeof v is 'function'
      (@['view'].outlets[name=k.substr(1)] || @['view']._buildOutlet(name)).set v
    return
