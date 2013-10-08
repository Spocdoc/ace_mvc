Base = require './base'
Template = require './template'
Outlet = require 'outlet'
debugDom = global.debug 'ace:dom'
debugMvc = global.debug 'ace:mvc'
Configs = require './configs'
buildClasses = require './build_classes'
_ = require 'lodash-fork'

module.exports = class ViewBase extends Base
  @configs: new Configs

  constructor: (aceParent, aceName, settings) ->
    return new @constructor[aceParent.aceType] aceParent, aceName, settings unless @aceConfig

    if aceName? and typeof aceName is 'object'
      settings = aceName
      aceName = ''
    else unless settings?
      settings = {}

    @aceParent = aceParent
    @aceName = aceName || ''

    debugMvc "Building #{@}"

    super()

    @acePath = "#{@aceParent.acePath}/#{@aceName}"
    if components = @['ace'].aceComponents
      throw new Error "MVC components with the same parent must have distinct names." if components[@acePath]
      components[@acePath] = this

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

  _buildDollarString: do ->
    outletValueMethods = [
      'toggleClass'
      'text'
      'html'
      'view'
      'val'
    ]

    (dollar, methName, arg) ->
      e = @[dollar]

      if methName in outletValueMethods
        outlet = if arg instanceof Outlet then arg else new Outlet arg, this, true

        switch methName
          when 'toggleClass'
            outlet.addOutflow new Outlet =>
              unless @['ace']['booting'] and @['template']['bootstrapped']
                debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
                e[methName](dollar.substr(1), ''+outlet.value) if outlet.value

          when 'text','html'
            outlet.addOutflow new Outlet =>
              unless @['ace']['booting'] and @['template']['bootstrapped']
                if outlet.value
                  if @['domCache'][dollar] isnt (v = ''+(outlet.value ? ''))
                    @['domCache'][dollar] = v
                    debugDom "calling #{methName} in dom on #{dollar} with #{v}"
                    e[methName](v)

          when 'view'
            oldView = undefined
            outlet.addOutflow new Outlet =>
              oldView?['detach']()
              (oldView = outlet.value)?['appendTo'] e
              return

          else
            outlet.addOutflow new Outlet =>
              unless @['ace']['booting'] and @['template']['bootstrapped']
                if @['domCache'][dollar] isnt (v = ''+(outlet.value ? ''))
                  debugDom "calling #{methName} in dom on #{dollar} with #{outlet.value}"
                  e[methName](outlet.value)
      else
        switch methName
          when 'link'
            applyLink = (arg) =>
              if !arg?
                e['link'].call e, this
              else
                if typeof arg is 'string' or typeof arg[0] is 'string'
                  e['link'].apply e, [this].concat arg
                else
                  e['link'].apply e, arg
              return
            if typeof arg is 'function'
              @outlets["_link#{_.makeId()}"] = new Outlet (=> applyLink arg.call this), this, true
            else
              applyLink arg

          else
            if Array.isArray arg
              for arg, i in args = arg when typeof arg is 'function'
                args[i] = buildClasses.wrapFunction arg, this
              e[methName].apply e, args
            else
              if typeof arg is 'function'
                arg = buildClasses.wrapFunction arg, this
              e[methName].call e, arg
      return

  _buildDollar: ->
    for k,v of @aceConfig when k.charAt(0) is '$'
      if typeof v is 'string'
        @_buildDollarString k, v, @outlets[k.substr(1)]
      else # object
        for str, method of v
          @_buildDollarString k, str, (if typeof method is 'string' and @outlets[method] then @outlets[method] else method) #new Outlet method, this, true
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
