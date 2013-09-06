Outlet = require 'outlet'
clone = require 'diff-fork/clone'
$ = require 'dom-fork'

updateUrl = (ace, allArgs) ->
  if ace.lastUrl isnt currentUrl = ace.currentUrl()
    url = ace.linkUrl = (ace.lastUrl = currentUrl).clone()
    ace.linkUrl.reform host: null
    if query = ace.linkUrl.query
      query = clone query
    else
      query = {}
  else
    url = ace.linkUrl
    query = url.query || {}

  if ace.hash
    delete query['']
    url.reform query: query
    if urlHash = ace.hash url.href
      allArgs[0] = urlHash

  query[''] = allArgs
  url.reform query: query
  url.href

$['fn']['extend']
  'link': (component, methodName, args...) ->
    nodeName = @['name']()
    ace = component['ace']
    hook = 'click'

    allArgs = ['',component.acePath, methodName].concat args

    if canHref = nodeName is 'a'
      @attr 'href', updateUrl(ace, allArgs)
    else if canAction = nodeName is 'form'
      @attr 'action', updateUrl(ace, allArgs)
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
        @attr 'href', updateUrl(ace, allArgs)
      else if canAction
        @attr 'action', updateUrl(ace, allArgs)
    return this
