$ = global.$
debug = global.debug 'ace:mvc'
utils = require './utils'

configs = new (require('./configs'))

getDomIds = do ->
  helper = (ids, dom) ->
    for child in dom.children()
      child = $(child)
      ids.push(id) if (id = child.attr('id'))?
      helper(ids, child)
    ids

  (dom) -> helper [], dom

module.exports = class TemplateBase
  @name = 'Template'

  @add: (type, domString) -> configs.add type, {domString}

  @finish: ->
    types = {}
    for type,config of configs.configs
      types[type] = class Template extends TemplateBase
        _type: type
        _config: config
    TemplateBase[k] = v for k,v of types
    return

  constructor: (@_parent, @_name) ->
    debug "Building #{@}"

    unless (config = @_config).$root
      $root = config.$root = $(config.domString)
      if $root.length > 1 or $root.attr('id')? or $root.attr('class')
        $root = config.$root = $('<div></div>').append($root)
      config.ids = getDomIds $root

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

    unless !prev && (@['$root'] = @$['root'] = globals.$root.find("##{@_prefix}")).length
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
