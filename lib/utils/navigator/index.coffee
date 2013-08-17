Url = require '../url'
debug = global.debug 'ace:navigator'
{include} = require '../mixin'

replaceInterval = 2000
replaceLastCall = 0
replaceTimeoutId = 0

urls = []
routeFn = null
routeCtx = null
index = 0
ignoreCount = 0
useHash = null
iframe = null

include Url,

  hasHashPath: do ->
    regex = /^#\d+/
    -> @hash and regex.test @hash

  index: do ->
    regex = /^#(\d+)/
    ->
      if (tmp = @hash and regex.exec(@hash)?[1])
        +tmp

  hasPath: -> @path.length > 1

  hashPath: do ->
    regex = /^#\d+(\/[^#]*)/
    -> @hash?.match(regex)?[1] || '/'

  hashHash: do ->
    regex = /^#.*?#(.*)$/
    -> @hash?.match(regex)?[1]

  stripHashPath: ->
    @reform
      hash: @hashHash() || ''
      path: if @hasHashPath() then @hashPath() else @path

  hashHref: ->
    "##{index}#{@path}#{@hash || ''}"


listen = (event, fn) ->
  if window.addEventListener
    window.addEventListener event, fn
  else if window.attachEvent
    window.attachEvent "on#{event}", fn
  return

navigator = (url) ->
  url = new Url url, navigator.url unless url instanceof Url
  if url.href isnt navigator.url.href
    if url.pathname is navigator.url.pathname
      replaceThrottled url
    else
      push url
  return

doReplace = (now=new Date) ->
  replaceLastCall = now
  replaceTimeoutId = null

  if useHash
    hash = navigator.url.hashHref()

    ++ignoreCount
    window.location.replace hash
    iframe?.location.replace hash

  else
    window.history.replaceState index, '', navigator.url.href

  return

replace = (url) ->
  clearTimeout replaceTimeoutId if replaceTimeoutId?
  urls[index] = navigator.url = url
  doReplace()
  return

replaceThrottled = (url) ->
  url = new Url url unless url instanceof Url
  urls[index] = navigator.url = url

  now = new Date
  remaining = replaceInterval - (now - replaceLastCall)

  if remaining <= 0
    clearTimeout replaceTimeoutId if replaceTimeoutId?
    doReplace now
  else unless replaceTimeoutId?
    replaceTimeoutId = setTimeout doReplace, replaceInterval

  return

push = (url) ->
  url = new Url url unless url instanceof Url

  if replaceTimeoutId?
    clearTimeout replaceTimeoutId
    doReplace()

  urls[++index] = navigator.url = url

  if useHash
    ++ignoreCount
    iframe?.document.open().close()
    window.location.hash = url.hashHref()
    iframe?.location.href = window.location.href
  else
    window.history.pushState index, '', url.href

  return

urlchange = ->
  if ignoreCount
    --ignoreCount
  else
    if replaceTimeoutId?
      clearTimeout replaceTimeoutId
      replaceTimeoutId = null

    newUrl = new Url(window.location.href)

    if newUrl.hasHashPath()
      newIndex = newUrl.index()
      newUrl.stripHashPath()
    else unless useHash
      newIndex = window.history.state

    if !newIndex? or (newIndex is index and newUrl.href isnt navigator.url.href)
      newIndex = urls.length
      urls[newIndex] = newUrl
      replaceWith = newUrl if useHash

    if newIndex isnt index
      index = newIndex

      debug "Got url change from #{navigator.url} to #{newUrl}"

      storedUrl = urls[newIndex]

      if (replaceWith ||= if storedUrl and storedUrl.href isnt newUrl.href then storedUrl else null)
        replace replaceWith
      else
        navigator.url = urls[newIndex] = newUrl

      routeFn.call routeCtx, navigator.url.href, index
  return

module.exports = (route, ctx) ->
  unless navigator.url

    routeFn = route
    routeCtx = ctx

    if /msie [\w.]+/.exec(window.navigator.userAgent.toLowerCase()) and (document.documentMode || 0) <= 7
      iframe = $('<iframe src="javascript:0" tabindex="-1" />').hide().appendTo('body')[0].contentWindow
      iframe.location.href = window.location.href

    navigator.url = new Url(window.location.href)

    if useHash = !window.history || !window.history.pushState
      index = navigator.url.index()
    else
      index = window.history.state

    index ||= 0
    urls[index] = navigator.url

    navigator.url.stripHashPath() if navigator.url.hasHashPath()
    doReplace() unless useHash

    ignoreCount = 0

    if iframe
      setInterval (->
        if iframe.location.href isnt window.location.href
          window.location.href = iframe.location.href
          urlchange()
      ), 300

    else if useHash
      listen 'hashchange', urlchange
    else
      ignoreCount = 1
      listen 'popstate', urlchange

  else
    currentRoute = routeFn
    currentRouteCtx = routeCtx

    routeCtx = null

    routeFn = (url, index) ->
      currentRoute.call currentRouteCtx, url, index
      route.call ctx, url, index
      return

  navigator
