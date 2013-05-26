$ = global.$

class TemplateBase
  constructor: (@dom) ->

  lazy: ->
    return if @$root
    @$root = $(@dom)
    @$root = $('<div></div>').append(@$root) if @$root.length > 1 or @$root.attr('id')?
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
    TemplateBase[name] = new TemplateBase(domString)
    return this

  constructor: (@type, @parent, @name) ->
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

