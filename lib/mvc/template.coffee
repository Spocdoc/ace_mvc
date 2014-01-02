$ = require 'dom-fork'
debug = global.debug 'ace:mvc'
typeToClass = require 'manifest_mvc/type_to_class'

configs = new (require('./configs'))
NAME_ELEMS = [
  # "A"
  # "APPLET"
  # "BUTTON"
  # "FORM"
  # "FRAME"
  # "IFRAME"
  # "IMG"
  "INPUT"
  # "MAP"
  # "META"
  # "OBJECT"
  # "PARAM"
  "SELECT"
  "TEXTAREA"
]

getDomIds = do ->
  regexNotCapitalized = /^[^A-Z]/

  helper = (ids, dom) ->
    for child in dom.children()
      child = $(child)
      ids.push(id) if (id = child.attr('id'))? and regexNotCapitalized.test id
      helper(ids, child)
    ids

  (dom) -> helper [], dom

module.exports = class TemplateBase
  @add: (type, domString) -> configs.add type, {domString}

  @compile: ->
    types = {}
    for type,config of configs.configs
      types[type] = class Template extends TemplateBase
        aceType: type
        aceConfig: config
    TemplateBase[k] = v for k,v of types
    return

  aceConfig:
    domString: ''

  constructor: (@aceParent) ->
    debug "Building #{@}"

    unless (config = @aceConfig).$root
      unless ($root = $(config.domString)).length
        $root = $('<div>')
      else if $root.length > 1 or $root.attr('id')? or $root.attr('class')
        $root = $('<div>').append($root)
      config.ids = getDomIds config.$root = $root

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
        ($elem = @["$#{id}"] = @$[id] = @['$root'].find("##{id}"))
        .attr('id', "#{@acePrefix}-#{id}")
        .template = this
        if $elem.name() in NAME_ELEMS
          $elem.attr 'name', "#{@acePrefix}-#{id}"

      classes = "#{typeToClass @aceParent.aceType} root"
      if @aceParent['isPrimary'] and @aceParent.aceType isnt ppt = @aceParent.aceParent.aceType
        classes += " #{typeToClass ppt}"
      @['$root'].attr 'class', classes
    else
      @['bootstrapped'] = true
      debug "Bootstrapping template with rootId #{rootId}"
      for id in config.ids
        (@["$#{id}"] = @$[id] = @['$root'].find("##{@acePrefix}-#{id}"))
          .template = this

    # public
    @['acePrefix'] = @acePrefix
    @['aceParent'] = @aceParent

    debug "done building #{@}"

  toString: -> "Template [#{@aceType}][#{@acePrefix}]"
