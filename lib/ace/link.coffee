Outlet = require 'outlet'
clone = require 'diff-fork/clone'
$ = require 'dom-fork'

getHref = (ace, allArgs) ->
  if ace.lastUri isnt currentUri = ace.currentUri()
    uri = ace.linkUri = (ace.lastUri = currentUri).clone()
    if query = ace.linkUri.query()
      query = clone query
    else
      query = {}
  else
    uri = ace.linkUri
    query = uri.query()

  if ace.uriToken
    delete query[''] # so the uriToken excludes it
    uri.setQuery query
    allArgs[0] = ace.uriToken uri

  query[''] = allArgs
  uri.setQuery query
  uri.uri

$['fn']['extend']
  'link': (component, methodName, args...) ->
    nodeName = @['name']()
    ace = component['ace']
    hook = 'click'

    allArgs = ['',component.acePath, methodName].concat args

    if canHref = nodeName is 'a'
      @attr 'href', getHref(ace, allArgs)
    else if canAction = nodeName is 'form'
      @attr 'action', getHref(ace, allArgs)
      @attr 'method', 'post'
      @attr 'enctype', 'multipart/form-data'
      hook = 'submit'

    @[hook] (event) ->
      unless event.altKey or event.metaKey or event.ctrlKey or event.shiftKey
        Outlet.openBlock()
        try
          component[methodName].apply component, args
        finally
          Outlet.closeBlock()
          event.preventDefault()
        false
      else if canHref
        @attr 'href', getHref(ace, allArgs)
      else if canAction
        @attr 'action', getHref(ace, allArgs)
    return this
