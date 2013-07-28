Base = require './base'
Template = require './template'
Outlet = require '../utils/outlet'
debugDom = global.debug 'ace:dom'
debugMvc = global.debug 'ace:mvc'

configs = new (require('./configs'))

module.exports = class ViewBase extends Base
  @add: (type, config) -> configs.add type, config

  @finish: ->
    configs.applyMixins()

    types = {}
    for type,config of configs.configs
      types[type] = class View extends ViewBase
        aceType: type
        aceConfig: config

        @_applyStatic config
        @_applyOutlets config
        @_applyMethods config
    ViewBase[k] = v for k, v of types
    return

  constructor: (@aceParent, @aceName, settings={}) ->
    debugMvc "Building #{@}"

    super()

    Outlet.openBlock()
    prev = Outlet.auto; Outlet.auto = null
    try
      @_buildOutlets()
      @inWindow = @['inWindow'] = @outlets['inWindow'] = new Outlet false, this, true
      @_buildTemplate settings['template'] || @aceConfig['template'] || @aceType, settings
      @_buildDollar()
      @_applyConstructors settings
      @_setOutlets settings
    finally
      Outlet.auto = prev
      Outlet.closeBlock()

    debugMvc "done building #{@}"

  'View': ViewBase

  toString: -> "View [#{@aceType}][#{@aceName}]"

  'insertAfter': ($elem) ->
    @remove()
    @$container = $elem.parent()
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "insert #{@} after #{$elem}"
      $elem.after(@['$root'])
    @_setInWindow @$container

  'insertBefore': ($elem) ->
    @remove()
    @$container = $elem.parent()
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "insert #{@} before #{$elem}"
      $elem.before(@['$root'])
    @_setInWindow @$container

  'prependTo': ($container) ->
    @remove()
    @$container = $container
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "prepend #{@} to #{$container}"
      $container.prepend(@['$root'])
    @_setInWindow $container

  'appendTo': ($container) ->
    @remove()
    @$container = $container
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "append #{@} to #{$container}"
      $container.append(@['$root'])
    @_setInWindow $container

  'remove': ->
    return unless @$container
    @$container = undefined
    @inWindow.unset()
    @inWindow.set(false)
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "remove #{@} from #{@$container}"
      @['$root'].remove()
    return

  _setInWindow: ($container) ->
    if other = $container.template?.aceParent?.inWindow
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
          unless @['ace']['booting'] and @['template']['bootstrapped']
            debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
            e[methName](dollar.substr(1), ''+outlet.value)

      when 'text','html'
        outlet.addOutflow new Outlet =>
          unless @['ace']['booting'] and @['template']['bootstrapped']
            if @['domCache'][dollar] isnt (v = ''+outlet.value)
              @['domCache'][dollar] = v
              debugDom "calling #{methName} in dom on #{dollar} with #{v}"
              e[methName](v)

      else
        outlet.addOutflow new Outlet =>
          unless @['ace']['booting'] and @['template']['bootstrapped']
            debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
            e[methName](outlet.value)

    return

  _buildDollar: ->
    for k,v of @aceConfig when k.charAt(0) is '$'
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
