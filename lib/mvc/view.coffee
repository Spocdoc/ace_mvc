Base = require './base'
Template = require './template'
Outlet = require '../utils/outlet'
debugDom = global.debug 'ace:dom'
debugMvc = global.debug 'ace:mvc'
Configs = require './configs'

module.exports = class ViewBase extends Base
  @configs: new Configs

  constructor: (@aceParent, aceName, settings) ->
    if aceName? and typeof aceName is 'object'
      settings = aceName
      aceName = ''
    else unless settings?
      settings = {}

    @aceName = aceName

    debugMvc "Building #{@}"

    super()

    Outlet.openBlock()
    prev = Outlet.auto; Outlet.auto = null
    try
      @_buildOutlets()
      @inWindow = @['inWindow'] = @outlets['inWindow'] = new Outlet false, this, true
      @_buildTemplate settings['template'] || @aceConfig['template'] || @aceType, settings
      @_buildDollar()
      @_runConstructors settings
      @_setOutlets settings
    finally
      Outlet.auto = prev
      Outlet.closeBlock()

    debugMvc "done building #{@}"

  varPrefix: '$'
  'View': ViewBase

  toString: -> "View [#{@aceType}][#{@aceName}]"

  'insertAfter': ($elem) ->
    @['detach']()
    $elem = $elem['$root'] || $elem['view']['$root'] if $elem instanceof Base
    @$container = $elem.parent()
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "insert #{@} after #{$elem}"
      $elem.after(@['$root'])
    @_setInWindow @$container

  'insertBefore': ($elem) ->
    @['detach']()
    $elem = $elem['$root'] || $elem['view']['$root'] if $elem instanceof Base
    @$container = $elem.parent()
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "insert #{@} before #{$elem}"
      $elem.before(@['$root'])
    @_setInWindow @$container

  'prependTo': ($container) ->
    @['detach']()
    $container = $container['$container'] || $container['view']['$container'] if $container instanceof Base
    @$container = $container
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "prepend #{@} to #{$container}"
      $container.prepend(@['$root'])
    @_setInWindow $container

  'appendTo': ($container) ->
    @['detach']()
    $container = $container['$container'] || $container['view']['$container'] if $container instanceof Base
    @$container = $container
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "append #{@} to #{$container}"
      $container.append(@['$root'])
    @_setInWindow $container

  'detach': ->
    return unless @$container
    @$container = undefined
    @inWindow.unset()
    @inWindow.set(false)
    unless @['ace']['booting'] and @['template']['bootstrapped']
      debugDom "detach #{@} from #{@$container}"
      @['$root'].detach()
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

      when 'view'
        oldView = undefined
        outlet.addOutflow new Outlet =>
          oldView?.detach()
          (oldView = outlet.value)?['appendTo'] e
          return

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
    else
      @['template'] =  new (Template[arg] || Template) this

    @['domCache'] = {}

    @$ = {}
    @$[k] = @["$#{k}"] = v for k,v of @['template'].$

    return
