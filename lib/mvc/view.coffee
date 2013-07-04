debugDom = global.debug 'ace:dom'
debugMvc = global.debug 'ace:mvc'
debugCascade = global.debug 'ace:cascade'

configs = new (require('./configs'))

module.exports = (pkg) ->
  cascade = pkg.cascade
  mvc = pkg.mvc

  mvc.Global.prototype['View'] = mvc.View = class View extends mvc.ControllerBase
    constructor: (config, settings) ->
      debugCascade "creating new view",@_type,@_name
      super config, settings

    'insertAfter': ($elem) ->
      @remove()
      $container = $elem.parent()
      debugDom "insert #{@} after #{$elem}"
      @$container = $container
      $elem.after(@['$root'])
      @_setInWindow $container

    'insertBefore': ($elem) ->
      @remove()
      $container = $elem.parent()
      debugDom "insert #{@} before #{$elem}"
      @$container = $container
      $elem.before(@['$root'])
      @_setInWindow $container

    'prependTo': ($container) ->
      @remove()
      debugDom "prepend #{@} to #{$container}"
      @$container = $container
      $container.prepend(@['$root'])
      @_setInWindow $container

    'appendTo': ($container) ->
      @remove()
      debugDom "append #{@} to #{$container}"
      @$container = $container
      $container.append(@['$root'])
      @_setInWindow $container

    'remove': ->
      return unless @$container
      debugDom "remove #{@} from #{@$container}"
      @$container = undefined
      @inWindow.unset()
      @inWindow.set(false)
      @['$root'].remove()
      return

    _setInWindow: ($container) ->
      if other = $container.template?._parent?.inWindow
      else
        for parent in $container.parents()
          (break) if other = parent.template?.view?.inWindow

      @inWindow.set(other || true)
      return

    _buildDollarString: (dollar, methName, outlet) ->
      e = @[dollar]
      outflows = outlet.outflows

      switch methName
        when 'toggleClass'
          outflows.add =>
            debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
            e[methName](dollar.substr(1), ''+outlet.value)

        when 'text','html'
          outflows.add =>
            if @['domCache'][dollar] isnt (v = ''+outlet.value)
              @['domCache'][dollar] = v
              debugDom "calling #{methName} in dom on #{dollar} with #{v}"
              e[methName](v)

        else
          outflows.add =>
            debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
            e[methName](outlet.value)

      return

    _buildDollar: (config) ->
      for k,v of config when k.charAt(0) is '$'
        if typeof v is 'string'
          @_buildDollarString k, v, @outlets[k.substr(1)]
        else # object
          for str, method of v
            @_buildDollarString k, str, new @Outlet method, k
      return

    _buildTemplate: (arg) ->
      if arg instanceof @['Template']
        @['template'] = arg
      else # string
        @['template'] =  new @['Template'][arg] this

      @['domCache'] = {}

      @$ = {}
      @$[k] = @["$#{k}"] = v for k,v of @['template'].$

      return

  for _type,_config of configs.configs
    mvc.View[_type] = class View extends mvc.View
      type = _type
      config = _config

      @name = 'View'
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

          @inWindow = @['inWindow'] = @outlets['inWindow'] = new @Outlet false

          @_buildTemplate settings['template'] || config['template'] || type, settings
          @_buildDollar config
          @_applyConstructors config, settings
          @_setOutlets settings

        debugMvc "done building #{@}"
        @Outlet.auto = prev

  mvc.View

module.exports.add = (type,config) -> configs.add type,config
module.exports.finish = -> configs.applyMixins()
