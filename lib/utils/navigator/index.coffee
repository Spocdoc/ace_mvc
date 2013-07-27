Url = require '../url'
debug = global.debug 'ace:navigator'

class NavigatorUrl extends Url
  hasHashPath: -> @hash?.startsWith '#/'
  hasPath: -> @path.length > 1

  hashPath: do ->
    regex = /^#(\/[^#]*)/

    (url=@) ->
      url.hash?.match(regex)?[1] || '/'

  hashHash: do ->
    regex = /^#.*?#(.*)$/

    (url=@) ->
      url.hash?.match(regex)?[1]

  stripHash: ->
    @reform
      hash: @hashHash() || ''
      path: if @hasPath() then @path else @hashPath()

listen = (event, fn) ->
  if window.addEventListener
    window.addEventListener event, fn
  else if window.attachEvent
    window.attachEvent "on#{event}", fn
  return

module.exports = (route, ctx) ->
  navigator = (url) ->
    url = new NavigatorUrl url, navigator.url unless url instanceof NavigatorUrl
    if url.href isnt navigator.url.href
      if url.path is navigator.url.path then replace url else push url
    return

  formHashUrl = ->
    navigator.url.clone().reform
      path: '/'
      hash: "##{navigator.url.path}#{navigator.url.hash || ''}"

  replace = (url) ->
    prev = navigator.url
    navigator.url = url

    if useHash
      ++ignoreCount
      if prev.path != url.path
        window.location.replace formHashUrl().href
      else
        window.location.replace formHashUrl().hash
    else
      window.history.replaceState null, '', url.href

    return

  push = (url) ->
    navigator.url = url

    if useHash
      ++ignoreCount
      window.location.href = formHashUrl().href
    else
      window.history.pushState null, '', url.href

    return

  urlchange = (event) =>
    if ignoreCount
      --ignoreCount
    else
      newUrl = new NavigatorUrl(event.newURL || window.location.href)
      newUrl.stripHash() if newUrl.hasHashPath()

      if newUrl.href isnt navigator.url.href
        debug "Got url change from #{navigator.url} to #{newUrl}"
        route.call ctx, (navigator.url = newUrl).href
    return

  useHash = !window.history || !window.history.pushState
  # useHash = true #TODO DEBUG
  navigator.url = new NavigatorUrl(window.location.href)

  replace navigator.url.stripHash() if navigator.url.hasHashPath()
  ignoreCount = 0

  if useHash
    listen 'hashchange', urlchange
  else
    ignoreCount = 1
    listen 'popstate', urlchange

  navigator
