$ = global.$
Outlet = require '../cascade/outlet'
debugMVC = global.debug 'ace:mvc'
utils = require './utils'

class Config
  constructor: (@dom, @_type) ->

  lazy: ->
    return if @$root
    @$root = $(@dom)
    if @$root.length > 1 or @$root.attr('id')? or @$root.attr('class')
      @$root = $('<div></div>').append(@$root)
    @ids = @constructor._getIds(@$root)

  @_getIds: do ->
    helper = (ids, dom) ->
      for child in dom.children()
        child = $(child)
        ids.push(id) if (id = child.attr('id'))?
        helper(ids, child)
      ids

    (dom) -> helper [], dom

class Template
  @add: (type, domString) ->
    throw new Error("Template: already added #{type}") if Config[type]?
    Config[type] = new Config(domString, type)
    return this

  constructor: (@_type, @_name) ->
    prev = Outlet.auto; Outlet.auto = null
    debugMVC "Building #{@}"
    @_path = @_parent._path
    @_path = @_path.concat(@_name) if @_name
    @_prefix = @_path.join('-') || "ace"
    @_prefix = "ace#{@_prefix}" if @_prefix.charAt(0) is '-'
    @$ = {}
    base = Config[@_type]
    base.lazy()
    @_build(base)

    # api
    @['$root'] = @$root
    @$root.addClass utils.makeClassName(@_parent._type)
    debugMVC "done building #{@}"
    Outlet.auto = prev

  toString: ->
    "#{@constructor.name} [#{@_type}] name [#{@_name}]"


  _build: (base) ->
    @$root = base.$root.clone()
    @$root.attr('id',@_prefix)
    @$['root'] = @$root

    for id in base.ids
      (@["$#{id}"] = @$[id] = @$root.find("##{id}"))
      .attr('id', "#{@_prefix}-#{id}")
      .template = this
    return

module.exports = Template

