Url = require '../url'
debug = global.debug 'ace:navigator'

replaceInterval = 2000
replaceLastCall = 0
replaceTimeoutId = 0
replaceUrl = null

urls = {}
routeFn = null
routeCtx = null
index = 0
ignoreCount = 0
useHash = null

class NavigatorUrl extends Url
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
      path: if @hasPath() then @path else @hashPath()

  formHashUrl: ->
    @clone().reform
      path: '/'
      hash: "##{index}#{@path}#{@hash || ''}"

listen = (event, fn) ->
  if window.addEventListener
    window.addEventListener event, fn
  else if window.attachEvent
    window.attachEvent "on#{event}", fn
  return

navigator = (url) ->
  url = new NavigatorUrl url, navigator.url unless url instanceof NavigatorUrl
  if url.href isnt navigator.url.href
    if url.pathname is navigator.url.pathname
      replaceThrottled url
    else
      push url
  return

doReplace = (now=new Date) ->
  replaceLastCall = now
  replaceTimeoutId = null

  urls[index] = navigator.url = replaceUrl

  if useHash
    prev = new NavigatorUrl window.location.href
    next = replaceUrl.formHashUrl()

    if prev.path != next.path
      ++ignoreCount
      window.location.replace next.href
    else if prev.hash != next.hash
      ++ignoreCount
      window.location.replace next.hash

  else
    window.history.replaceState index, '', replaceUrl.href

  return

replace = (url) ->
  clearTimeout replaceTimeoutId if replaceTimeoutId?
  replaceUrl = url
  doReplace()
  return

replaceThrottled = (url) ->
  now = new Date
  remaining = replaceInterval - (now - replaceLastCall)
  replaceUrl = url

  if remaining <= 0
    clearTimeout replaceTimeoutId
    doReplace now
  else
    replaceTimeoutId = setTimeout doReplace, replaceInterval unless replaceTimeoutId?

  return

push = (url) ->
  if replaceTimeoutId?
    clearTimeout replaceTimeoutId
    doReplace()

  urls[++index] = navigator.url = url

  if useHash
    ++ignoreCount
    window.location.href = url.formHashUrl().href
  else
    window.history.pushState index, '', url.href

  return

urlchange = (event) ->
  if ignoreCount
    --ignoreCount
  else
    if replaceTimeoutId?
      clearTimeout replaceTimeoutId
      replaceTimeoutId = null
      urls[index] = replaceUrl

    newUrl = new NavigatorUrl(event.newURL || window.location.href)

    if newUrl.hasHashPath()
      newIndex = newUrl.index()
      newUrl.stripHashPath()
    else unless useHash
      newIndex = window.history.state

    if !newIndex? or (newIndex is index and newUrl.href isnt navigator.url.href)
      newIndex = index + 1
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

    navigator.url = new NavigatorUrl(window.location.href)

    # TODO DEBUG
    if useHash = true #!window.history || !window.history.pushState
      index = navigator.url.index()
    else
      index = window.history.state

    if navigator.url.hasHashPath() or (useHash and !index?)
      index ||= 0
      replace navigator.url.stripHashPath()
    else
      urls[index||=0] = navigator.url

    ignoreCount = 0

    if useHash
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
