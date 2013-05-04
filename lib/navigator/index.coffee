Url = require '../url'
Emitter = require '../events/emitter'
{include, extend} = require '../mixin/mixin'

class NavigatorUrl extends Url
  hasHashPath: do ->
    regex = /^#\d+/

    (url=@) ->
      if url.hash?
        ~url.hash.search(regex)

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


class Navigator
  include Navigator, Emitter

  constructor: (@window, @useHash=false) ->
    @useHash ||= !@window.history || !@window.history.pushState
    @url = new NavigatorUrl(@window.location.href)
    @index = 0
    @_urls = [@url]

    @_replace @_stripHash()

    if @useHash
      @_listen 'hashchange', @_urlchange
    else
      setTimeout (=> @_listen('popstate', @_urlchange)), 0

  _listen: (event, fn) ->
    if @window.addEventListener
      @window.addEventListener event, fn
    else if @window.attachEvent
      @window.attachEvent "on#{event}", fn
    return

  push: (url=@url) ->
    url = new NavigatorUrl url, @url unless url instanceof NavigatorUrl
    @url = url

    ++@index
    @_urls.splice(@index)
    @_urls[@index] = @url

    if @useHash
      @window.location.href = @_formHashUrl().href
    else
      @window.history.pushState @index, '', @url.href

    return @index

  replace: (url) ->
    url = new NavigatorUrl url, @url unless url instanceof NavigatorUrl
    return if url.href is @url.href
    @_replace url

  back: -> @go(-1)
  forward: -> @go(+1)
  go: (delta) ->
    @window.history.go(delta)
    return @index+delta

  _replace: (url) ->
    prev = @url
    @url = url
    @_urls[@index] = @url

    if @useHash
      if prev.path != @url.path
        @window.location.replace @_formHashUrl().href
      else
        @window.location.replace @_formHashUrl().hash
    else
      @window.history.replaceState @index, '', @url.href
    return @index

  _stripHash: (url=@url) ->
    if url.hasHashPath()
      url.reform
        hash: url.hashHash() || ''
        path: if url.hasPath() then url.path else url.hashPath()
    else
      url

  _formHashUrl: ->
    @url.clone().reform
      path: '/'
      hash: "##{@index}#{@url.path}#{@url.hash || ''}"

  _urlchange: (event) =>
    newUrl = new NavigatorUrl(event.newURL || @window.location.href)
    newIndex = if event.state? then +event.state else newUrl.hashIndex()

    if not isFinite(newIndex) or newUrl.href isnt @_urls[newIndex]?.href
      @_navigate newUrl
    else if newIndex != @index
      @index = newIndex
      @url = @_urls[newIndex]
      @emit 'navigate', @index
    
  _navigate: (newUrl) ->
    ++@index
    @_urls.splice(@index)
    @_replace newUrl
    @emit 'navigate', newUrl.href, @index


module.exports = Navigator
