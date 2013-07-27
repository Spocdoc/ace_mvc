Cookies = require '../index'

Cookies.prototype._build = (@sock) ->

Cookies.prototype.set = (name, value, expires) ->
  document.cookie = @_makeString(name,value,expires)

Cookies.prototype.get = (name) ->
  json = @toJSON()

  if @_prevDocCookies != docCookies = document.cookie
    @sock.emit 'cookies', json, ->
    @_prevDocCookies = docCookies

  json[name]

Cookies.prototype.toJSON = ->
  cookies = {}
  for cookie in document.cookie.split ';'
    [key,value] = cookie.split '='
    cookies[key] = @_parseValue value
  cookies

module.exports = (config) ->
  Cookies.domain = config.domain
  Cookies.secure = config.secure

