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
  @add: (type, domString) -> configs.add type, {domString}

  @finish: ->
    types = {}
    for type,config of configs.configs
      types[type] = class Template extends TemplateBase
        aceType: type
        aceConfig: config
    TemplateBase[k] = v for k,v of types
    return

  constructor: (@aceParent) ->
    debug "Building #{@}"

    unless (config = @aceConfig).$root
      $root = config.$root = $(config.domString)
      if $root.length > 1 or $root.attr('id')? or $root.attr('class')
        $root = config.$root = $('<div></div>').append($root)
      config.ids = getDomIds $root

    path = []
    elem = @aceParent
    while elem
      path.push name if name = elem.aceName
      elem = elem.aceParent
    rootId = path.reverse().join('-') || 'ace'
    @acePrefix = "#{rootId}-"

    @$ = {}

    unless (br = TemplateBase.bootRoot) && (@['$root'] = @$['root'] = br.find("##{rootId}")).length
      debug "Not bootstrapping template with rootId #{rootId}"
      @$['root'] = @['$root'] = config.$root.clone()
      @['$root'].attr('id',rootId)

      for id in config.ids
        (@["$#{id}"] = @$[id] = @['$root'].find("##{id}"))
        .attr('id', "#{@acePrefix}-#{id}")
        .template = this
    else
      @['bootstrapped'] = true
      debug "Bootstrapping template with rootId #{rootId}"
      for id in config.ids
        (@["$#{id}"] = @$[id] = @['$root'].find("##{@acePrefix}-#{id}"))
          .template = this

    @['$root'].addClass utils.makeClassName(@aceParent.aceType)

    # public
    @['acePrefix'] = @acePrefix
    @['aceParent'] = @aceParent

    debug "done building #{@}"

  toString: -> "Template [#{@aceType}][#{@acePrefix}]"
