Outlet = require '../utils/outlet'
clone = require '../utils/clone'

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

  query[''] = allArgs
  url.reform query: query
  url.href

global.$['fn']['extend']
  'link': (component, methodName, args...) ->
    nodeType = @['type']()
    ace = component['ace']
    hook = 'click'

    allArgs = Array.prototype.slice.call arguments, 0
    allArgs[0] = component.acePath

    if canHref = nodeType is 'a'
      @attr 'href', updateUrl(ace, allArgs)
    else if canAction = nodeType is 'form'
      @attr 'action', updateUrl(ace, allArgs)
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

