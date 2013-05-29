$ = global.$
Outlet = require '../cascade/outlet'
debugMVC = global.debug 'ace:mvc'

class TemplateBase
  constructor: (@dom, @name) ->

  lazy: ->
    return if @$root
    @$root = $(@dom)
    if @name is 'body'
      @$root = $('<body></body>').append(@$root)
    else if @$root.length > 1 or @$root.attr('id')? or @$root.attr('class')
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
  @add: (name, domString) ->
    throw new Error("Template: already added #{name}") if @[name]?
    TemplateBase[name] = new TemplateBase(domString, name)
    return this

  constructor: (@type, @parent, @name) ->
    prev = Outlet.auto; Outlet.auto = null
    debugMVC "Building #{@}"
    @path = @parent.path
    @path = @path.concat(@name) if @name
    @prefix = @path.join('-') || "ace"
    @prefix = "ace#{@prefix}" if @prefix[0] is '-'
    @$ = {}
    base = TemplateBase[@type]
    base.lazy()
    @_build(base)

    # api
    @['$root'] = @$root
    @$root.addClass @parent.type.replace('/','-')
    debugMVC "done building #{@}"
    Outlet.auto = prev

  toString: ->
    "#{@constructor.name} [#{@type}] name [#{@name}]"


  _build: (base) ->
    @$root = base.$root.clone()
    @$root.attr('id',@prefix)
    @$['root'] = @$root

    for id in base.ids
      (@["$#{id}"] = @$[id] = @$root.find("##{id}"))
      .attr('id', "#{@prefix}-#{id}")
      .template = this
    return

module.exports = Template

