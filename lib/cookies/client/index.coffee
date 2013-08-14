Cookies = require '../index'
debug = global.debug 'ace:cookies'
debugError = global.debug 'ace:error'

Cookies.prototype._build = (@sock) ->

Cookies.prototype.set = (name, value, expires) ->
  try
    debug "setting cookie to [#{@_makeString(name,value,expires)}]"
    document.cookie = @_makeString(name,value,expires)
    debug "cookie is now [#{document.cookie}]"
  catch _error
    debugError "#{_error.name}: #{_error.message}\n #{_error.stack}" if _error
  return

Cookies.prototype.get = (name) ->
  json = @toJSON()

  if @_prevDocCookies != docCookies = document.cookie
    @sock.emit 'cookies', json, ->
    @_prevDocCookies = docCookies

  json[name]

Cookies.prototype.toJSON = ->
  cookies = {}
  debug "toJSON on cookies [#{document.cookie}]"
  if cookieStr = document.cookie
    for cookie in cookieStr.split ';'
      [key,value] = cookie.split '='
      debug "parsingValue on #{value}"
      cookies[key] = @_parseValue value
  cookies

module.exports = (config) ->
  Cookies.domain = config.domain
  Cookies.secure = config.secure

