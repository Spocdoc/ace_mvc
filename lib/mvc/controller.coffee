Base = require './base'
View = require './view'
Outlet = require 'outlet'
debugCascade = global.debug 'ace:cascade'
debugMvc = global.debug 'ace:mvc'
Configs = require './configs'

module.exports = class Controller extends Base
  @configs: new Configs

  constructor: (aceParent, aceName, settings) ->
    throw new Error "Controllers must have names." unless aceName or aceParent is aceParent.globals['ace']
    return new @constructor[aceParent.aceType] aceParent, aceName, settings unless @aceConfig

    if aceName? and typeof aceName is 'object'
      settings = aceName
      aceName = ''
    else unless settings?
      settings = {}

    @aceParent = aceParent
    @aceName = aceName || ''
    @controllers = {}

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
      @_buildView settings['view'] || @aceConfig['view'] || @aceType, settings
      @_buildDollar()
      @_runConstructors settings
      @_setOutlets settings
    finally
      Outlet.auto = prev
      Outlet.closeBlock()

    debugMvc "done building #{@}"

  'appendTo': ($container, view) -> @['view']['appendTo']($container, view)
  'prependTo': ($container, view) -> @['view']['prependTo']($container, view)
  'insertBefore': ($elem, view) -> @['view']['insertBefore']($elem, view)
  'insertAfter': ($elem, view) -> @['view']['insertAfter']($elem, view)
  'detach': -> @['view']['detach']()

  'Controller': Controller
  'View': View

  toString: -> "Controller [#{@aceType}][#{@acePath}]"

  _buildView: (arg, settings) ->
    if arg instanceof View
      @['view'] = arg
    else if typeof arg is 'string'
      return unless clazz = View[arg]
      @['view'] = new clazz this, undefined, 'isPrimary': true
    else
      break for k,v of arg
      v['isPrimary'] ?= true
      @['view'] = new View[k] this, undefined, v

    @$ = {}
    @outlets["$#{k}"] = @["$#{k}"] = @$[k] = v for k, v of @['view'].outlets
    return

  _buildDollar: ->
    for k,v of @aceConfig when k.charAt(0) is '$'
      v = new Outlet v, this, true if typeof v is 'function'
      (@['view'].outlets[name=k.substr(1)] || @['view']._buildOutlet(name)).set v
    return

