debugCascade = global.debug 'ace:cascade'
debugMvc = global.debug 'ace:mvc'

configs = new (require('./configs'))

module.exports = (pkg) ->
  cascade = pkg.cascade
  mvc = pkg.mvc

  mvc.Global.prototype['Controller'] = mvc.Controller = class Controller extends mvc.ControllerBase
    constructor: (config, settings) ->
      debugCascade "creating new controller",@_type,@_name
      super config, settings

    'appendTo': ($container) -> @['view']['appendTo']($container)
    'prependTo': ($container) -> @['view']['prependTo']($container)
    'insertBefore': ($elem) -> @['view']['insertBefore']($elem)
    'insertAfter': ($elem) -> @['view']['insertAfter']($elem)
    'remove': -> @['view']['remove']()

    _buildView: (arg, settings) ->
      if arg instanceof mvc.View
        @['view'] = arg
      else if typeof arg is 'string'
        @['view'] = new @['View'][arg] this
      else
        break for k,v of arg
        outlet.set @['view'] = new @['View'][k] this, undefined, v

      @$ = {}
      @outlets["$#{k}"] = @["$#{k}"] = @$[k] = v for k, v of @['view'].outlets
      return

    _buildDollar: (config) ->
      for k,v of config when k.charAt(0) is '$'
        v = new @Outlet(v, k) if typeof v is 'function'
        (@['view'].outlets[name=k.substr(1)] || @['view']._buildOutlet(name)).set v
      return

  for _type,_config of configs.configs

    mvc.Controller[_type] = class Controller extends mvc.Controller
      type = _type
      config = _config

      @name = 'Controller'
      _type: type

      @_applyStatic config
      @_applyOutlets config
      @_applyMethods config

      constructor: (@_parent, @_name, settings={}) ->
        super()

        prev = @Outlet.auto; @Outlet.auto = null
        debugMvc "Building #{@}"

        cascade.Cascade.Block =>

          @_buildOutlets()
          @_buildView settings['view'] || config['view'] || type, settings
          @_buildDollar config
          @_applyConstructors config, settings
          @_setOutlets settings

        debugMvc "done building #{@}"
        @Outlet.auto = prev

  mvc.Controller

module.exports.add = (type,config) -> configs.add type,config
module.exports.finish = -> configs.applyMixins()

