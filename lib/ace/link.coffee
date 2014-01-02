Outlet = require 'outlet'
clone = require 'diff-fork/clone'
$ = require 'dom-fork'
isTouch = global.document? and 'ontouchstart' of global.document.documentElement

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

$['link'] = (component, methodName, args...) ->
  # if component['ace'].onServer
    allArgs = ['',component.acePath, methodName].concat args
    getHref(component['ace'], allArgs)
  # else
  #   'javascript:void()'

$['fn']['extend']
  # trigger is 'click', 'mouseup', or 'mousedown'
  #
  # alternate arguments: trigger, component, selector, fn
  #   where fn is called with the matched event target and should return an
  #   array with component, methodName and args
  'link': (trigger, component, methodName, args...) ->
    nodeName = @['name']()
    ace = component['ace']

    trigger = 'touchend' if isTouch and trigger is 'click'

    suffix = if typeof (fn = args[0]) is 'function' then '' else '.link'

    switch trigger
      when 'mousedown'
        hook = if isTouch then "touchstart#{suffix}" else "mousedown#{suffix}"
      when 'mouseup'
        hook = if isTouch then "touchend#{suffix}" else "mouseup#{suffix}"
      else
        hook = "#{trigger}#{suffix}"

    unless suffix
      # using selector method

      selector = methodName

      @on hook, selector, (event) =>
        $target = $(event.currentTarget)
        [methodName, args...] = fn $target, event

        unless event.altKey or event.metaKey or event.ctrlKey or event.shiftKey
          keepDefault = false
          Outlet.openBlock()
          try
            if true is component[methodName].apply component, args
              keepDefault = true
          finally
            Outlet.closeBlock()
            event.preventDefault() unless keepDefault
        else
          allArgs = ['',component.acePath, methodName].concat args
          $target.attr 'href', getHref(ace, allArgs)
        return

      if trigger isnt 'click'
        @on 'click', selector, (event) =>
          unless event.altKey or event.metaKey or event.ctrlKey or event.shiftKey
            event.preventDefault()
          else
            $target = $(event.currentTarget)
            $target.attr 'href', getHref(ace, ['',component.acePath].concat fn $target)
          return

    else
      canHref = nodeName is 'A'
      canAction = nodeName is 'FORM'

      hook = 'submit.link' if canAction
      @off '.link'

      unless methodName
        if canHref
          @removeAttr 'href'
        else if canAction
          @removeAttr 'action'
      else
        allArgs = ['',component.acePath, methodName].concat args

        if canHref
          @attr 'href', getHref(ace, allArgs)
        else if canAction
          @attr 'action', getHref(ace, allArgs)
          @attr 'method', 'post'
          @attr 'enctype', 'multipart/form-data'

        @on hook, (event) =>
          unless event.altKey or event.metaKey or event.ctrlKey or event.shiftKey
            keepDefault = false
            Outlet.openBlock()
            try
              if true is component[methodName].apply component, args
                keepDefault = true
            finally
              Outlet.closeBlock()
              event.preventDefault() unless keepDefault
          else if canHref
            @attr 'href', getHref(ace, allArgs)
          else if canAction
            @attr 'action', getHref(ace, allArgs)
          return

        if !canAction and trigger isnt 'click'
          @on 'click.link', (event) =>
            unless event.altKey or event.metaKey or event.ctrlKey or event.shiftKey
              event.preventDefault()
            else if canHref
              @attr 'href', getHref(ace, allArgs)
            else if canAction
              @attr 'action', getHref(ace, allArgs)
            return

    return this
