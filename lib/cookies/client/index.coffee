Cookies = require '../index'

Cookies.prototype._build = ->
  @_cache = {}
  for cookie in document.cookie.split /;\s*/
    i = cookie.indexOf '='
    @_cache[cookie.substr(0,i)] = @_parseValue cookie.substr(i+1)
  return

Cookies.prototype.set = (name, value, expires) ->
  @_cache[name] = value
  document.cookie = @_makeString(name,value,expires)

Cookies.prototype.get = (name) ->
  @_cache[name]

module.exports = (config) ->
  Cookies.domain = config.domain
  Cookies.secure = config.secure

