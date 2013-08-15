Base = require './base'
View = require './view'
Outlet = require '../utils/outlet'
debugCascade = global.debug 'ace:cascade'
debugMvc = global.debug 'ace:mvc'
Configs = require './configs'

module.exports = class Controller extends Base
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
      @_buildView settings['view'] || @aceConfig['view'] || @aceType, settings
      @_buildDollar()
      @_runConstructors settings
      @_setOutlets settings
    finally
      Outlet.auto = prev
      Outlet.closeBlock()

    debugMvc "done building #{@}"

  'appendTo': ($container) -> @['view']['appendTo']($container)
  'prependTo': ($container) -> @['view']['prependTo']($container)
  'insertBefore': ($elem) -> @['view']['insertBefore']($elem)
  'insertAfter': ($elem) -> @['view']['insertAfter']($elem)
  'detach': -> @['view']['detach']()

  'Controller': Controller
  'View': View

  toString: -> "Controller [#{@aceType}][#{@aceName}]"

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
    for k,v of @aceConfig when k.charAt(0) is '$'
      v = new Outlet v, this, true if typeof v is 'function'
      (@['view'].outlets[name=k.substr(1)] || @['view']._buildOutlet(name)).set v
    return
