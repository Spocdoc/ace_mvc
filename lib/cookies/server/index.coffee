Cookies = require '../index'
debug = global.debug 'ace:cookies'
connect = require 'connect'

Cookies.prototype._build = (@req, @res) ->

Cookies.prototype.set = (name, value, expires) ->
  @res.setHeader 'Set-Cookie', @_makeString(name, value, expires)

Cookies.prototype.get = (name) ->
  (value = @req.cookies?[name]) && @_parseValue value

module.exports = (config, app) ->
  app.use connect.cookieParser()
  Cookies.domain = config.domain
  Cookies.secure = config.secure
