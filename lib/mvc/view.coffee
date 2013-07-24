Base = require './base'
Template = require './template'
debugDom = global.debug 'ace:dom'
debugMvc = global.debug 'ace:mvc'

configs = new (require('./configs'))

module.exports = class View extends Base
  @name = 'View'

  @add: (type, config) -> configs.add type, config

  @finish: ->
    configs.applyMixins()

    ViewBase = View
    types = {}
    for type,config of configs.configs
      types[type] = class View extends ViewBase
        _type: type
        _config: config

        @_applyStatic config
        @_applyOutlets config
        @_applyMethods config
    ViewBase[k] = v for k, v of types
    return

  constructor: (@_parent, @_name, settings={}) ->
    debugMvc "Building #{@}"

    super()

    Outlet.openBlock()
    prev = Outlet.auto; Outlet.auto = null
    try
      @_buildOutlets()
      @inWindow = @['inWindow'] = @outlets['inWindow'] = new Outlet false, this, true
      @_buildTemplate settings['template'] || @_config['template'] || type, settings
      @_buildDollar()
      @_applyConstructors settings
      @_setOutlets settings
    finally
      Outlet.auto = prev
      Outlet.closeBlock()

    debugMvc "done building #{@}"

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

    switch methName
      when 'toggleClass'
        outlet.addOutflow new Outlet =>
          debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
          e[methName](dollar.substr(1), ''+outlet.value)

      when 'text','html'
        outlet.addOutflow new Outlet =>
          if @['domCache'][dollar] isnt (v = ''+outlet.value)
            @['domCache'][dollar] = v
            debugDom "calling #{methName} in dom on #{dollar} with #{v}"
            e[methName](v)

      else
        outlet.addOutflow new Outlet =>
          debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
          e[methName](outlet.value)

    return

  _buildDollar: ->
    for k,v of @_config when k.charAt(0) is '$'
      if typeof v is 'string'
        @_buildDollarString k, v, @outlets[k.substr(1)]
      else # object
        for str, method of v
          @_buildDollarString k, str, new Outlet method, this, true
    return

  _buildTemplate: (arg) ->
    if arg instanceof Template
      @['template'] = arg
    else # string
      @['template'] =  new Template[arg] this

    @['domCache'] = {}

    @$ = {}
    @$[k] = @["$#{k}"] = v for k,v of @['template'].$

    return
