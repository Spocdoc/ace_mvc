class Cookies
  constructor: (args...) ->
    @_build args...

  @prototype.unset = @prototype['unset'] = (name) ->
    @set name, 0, new Date(0)

  set: (name, value, expires) ->

  get: (name) ->

  _build: ->

  _makeString: (name, value, expires) ->
    unless expires
      expires = new Date()
      expires.setYear expires.getYear() + 1900 + 20

    try
      value = encodeURIComponent JSON.stringify value
    catch _error
      debug "Error encoding cookie value: #{value}"
      value = ''

    str = []
    str.push "#{name}=#{value}; Path=/; Expires=#{expires.toUTCString()};"
    str.push "Secure;" if Cookies.secure
    str.push "Domain=#{domain};" if domain = Cookies.domain
    str.join(' ')

  _parseValue: (value) ->
    try
      JSON.parse decodeURIComponent value
    catch _error
      debug "Error decoding cookie value: #{value}"
      undefined


module.exports = Cookies

