Cookies = require '../index'
debug = global.debug 'ace:cookies'
connect = require 'connect'

Cookies.prototype._build = (@req, @res, @sock) ->

Cookies.prototype.set = (name, value, expires) ->
  unless @sock.readOnly
    @res.setHeader 'Set-Cookie', @_makeString(name, value, expires)
  return

Cookies.prototype.get = (name) ->
  (value = @req.cookies?[name]) && @_parseValue value

Cookies.prototype.toJSON = ->
  cookies = {}
  for key, value of @req.cookies
    cookies[key] = @_parseValue value
  cookies

module.exports = (config, app) ->
  app.use connect.cookieParser()
  Cookies.domain = config.domain
  Cookies.secure = config.secure

