$ = global.$
debug = global.debug 'ace:mvc'
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

module.exports = class Template
  @name = 'Template'

  @add: (type, domString) ->
    throw new Error("Template: already added #{type}") if Config[type]?
    Config[type] = new Config(domString, type)
    return

  @finish: ->
    TemplateBase = Template
    for _type,_config of Config
      TemplateBase[_type] = class Template extends TemplateBase
        _type: type
        _config: _config
    return

  constructor: (@_parent, @_name) ->
    debug "Building #{@}"

    (config = @_config).lazy()

    path = []
    elem = this
    while elem
      path.push name if name = elem._name
      elem = elem._parent
    @_prefix = path.reverse().join('-') || 'ace'

    globals = @_parent.globals.Template
    bootstrapped = globals.bootstrapped ||= {}

    @$ = {}
    prev = bootstrapped[@_prefix]
    bootstrapped[@_prefix] = true

    unless !prev && (@['$root'] = @$['root'] = globals.$container.find("##{@_prefix}")).length
      debug "Not bootstrapping template with prefix #{@_prefix}"
      @$['root'] = @['$root'] = config.$root.clone()
      @['$root'].attr('id',@_prefix)

      for id in config.ids
        (@["$#{id}"] = @$[id] = @['$root'].find("##{id}"))
        .attr('id', "#{@_prefix}-#{id}")
        .template = this
    else
      debug "Bootstrapping template with prefix #{@_prefix}"
      for id in config.ids
        (@["$#{id}"] = @$[id] = @['$root'].find("##{@_prefix}-#{id}"))
          .template = this

    @['$root'].addClass utils.makeClassName(@_parent._type)

    debug "done building #{@}"

  toString: ->
    "#{@constructor.name} [#{@_type}] name [#{@_name}]"
