Url = require '../url'
debug = global.debug 'ace:navigator'

class NavigatorUrl extends Url
  hasHashPath: do ->
    regex = /^#\d+/

    (url=@) ->
      if url.hash?
        !!~url.hash.search(regex)
      else
        false

  hasPath: (url=@) ->
    url.path.length > 1

  hashPath: do ->
    regex = /^#\d+(\/[^#]*)/

    (url=@) ->
      url.hash?.match(regex)?[1] || '/'

  hashHash: do ->
    regex = /^#.*?#(.*)$/

    (url=@) ->
      url.hash?.match(regex)?[1]

  hashIndex: do ->
    regex = /^#(\d+)/

    (url=@) ->
      +url.hash?.match(regex)?[1]

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
      hash: "##{navigator.index}#{navigator.url.path}#{navigator.url.hash || ''}"

  replace = (url) ->
    prev = navigator.url
    navigator.url = url
    urls[navigator.index] = url

    if useHash
      ++ignoreCount
      if prev.path != url.path
        window.location.replace formHashUrl().href
      else
        window.location.replace formHashUrl().hash
    else
      window.history.replaceState navigator.index, '', url.href

    return

  push = (url) ->
    navigator.url = url

    ++navigator.index
    urls.splice(navigator.index)
    urls[navigator.index] = url

    if useHash
      ++ignoreCount
      window.location.href = formHashUrl().href
    else
      window.history.pushState navigator.index, '', url.href

    return

  urlchange = (event) =>
    if ignoreCount
      --ignoreCount
      return

    newUrl = new NavigatorUrl(event.newURL || window.location.href)
    newIndex = if event.state? then +event.state else newUrl.hashIndex()
    newUrl.stripHash() if newUrl.hasHashPath()

    debug "Got url change from #{navigator.url} to #{newUrl}"

    if not isFinite(newIndex) or newUrl.href isnt urls[newIndex]?.href
      debug "emitting new url navigate [#{newUrl}]"

      urls.splice ++navigator.index
      replace newUrl
      route.call ctx, navigator.url.href, navigator.index

    else if newIndex != navigator.index
      debug "emitting index navigate to [#{newIndex}]"
      navigator.url = urls[navigator.index = newIndex]
      route.call ctx, navigator.url.href, navigator.index

    return

  useHash = !window.history || !window.history.pushState
  useHash = true #TODO DEBUG
  navigator.url = new NavigatorUrl(window.location.href)
  navigator.index = 0
  urls = [navigator.url]

  replace navigator.url.stripHash() if navigator.url.hasHashPath()
  ignoreCount = 0

  if useHash
    listen 'hashchange', urlchange
  else
    ignoreCount = 1
    listen 'popstate', urlchange

  navigator
