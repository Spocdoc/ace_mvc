$ = global.$
debugMvc = global.debug 'ace:mvc'
debugBoot = global.debug 'ace:boot'
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

module.exports = (pkg) ->
  Outlet = pkg.cascade.Outlet
  mvc = pkg.mvc

  mvc.Global.prototype['Template'] = mvc.Template = class Template
    toString: ->
      "#{@constructor.name} [#{@_type}] name [#{@_name}]"

    bootstrapped = {} # re-used element ids from the server-rendered dom
    _build: (config) ->
      prev = bootstrapped[@_prefix]
      bootstrapped[@_prefix] = true

      unless !prev && (@['$root'] = @$['root'] = Template.$root?.find("##{@_prefix}")).length
        debugBoot "Not bootstrapping template with prefix #{@_prefix}"
        @$['root'] = @['$root'] = config.$root.clone()
        @['$root'].attr('id',@_prefix)

        for id in config.ids
          (@["$#{id}"] = @$[id] = @['$root'].find("##{id}"))
          .attr('id', "#{@_prefix}-#{id}")
          .template = this
      else
        debugBoot "Bootstrapping template with prefix #{@_prefix}"
        for id in config.ids
          (@["$#{id}"] = @$[id] = @['$root'].find("##{@_prefix}-#{id}"))
            .template = this

      return

  for _type,_config of Config
    mvc.Template[_type] = class Template extends mvc.Template
      type = _type
      config = _config

      @name = 'Template'
      _type: type

      _setPrefix: ->
        elem = this
        path = []

        while elem
          path.push name if name = elem._name
          elem = elem._parent

        @_prefix = path.reverse().join('-') || 'ace'

      constructor: (@_parent, @_name) ->
        prev = Outlet.auto; Outlet.auto = null
        debugMvc "Building #{@}"

        @_setPrefix()

        @$ = {}
        config.lazy()
        @_build(config)

        @['$root'].addClass utils.makeClassName(@_parent._type)

        debugMvc "done building #{@}"
        Outlet.auto = prev

module.exports.add = (type, domString) ->
  throw new Error("Template: already added #{type}") if Config[type]?
  Config[type] = new Config(domString, type)
  return

