# derived from node.js with substantial modification

{defaults: udefaults} = require '../mixin'
require '../polyfill'
querystring = require './querystring'

protocolPattern = /^([a-z0-9.+-]+:)/i
portPattern = /:[0-9]*$/

delims = ["<", ">", "\"", "`", " ", "\r", "\n", "\t"]
unwise = ["{", "}", "|", "\\", "^", "~", "`"].concat(delims)

nonHostChars = ["%", "/", "?", ";", "#", "'"].concat(unwise)
nonAuthChars = ["/", "@", "?", "#"].concat(delims)
hostnameMaxLen = 255

nonAsciiRegex = /[^\x20-\x7E]/g
nonHostRegex = new RegExp("[#{RegExp.escape(nonHostChars.join())}]")

autoEscape = ["'"].concat(delims)
autoEscapeRepl = {}
autoEscapeRepl[char] = escape(char) for char in autoEscape
autoEscapeRegex = new RegExp("[#{RegExp.escape(autoEscape.join())}]",'g')

class Url
  _pullAuth: (rest) ->
    return rest unless ~(atSign = rest.indexOf("@"))
    auth = rest.slice(0, atSign)
    (return rest if ~auth.indexOf(char)) for char in nonAuthChars
    @_setAuth auth
    rest.substr(atSign + 1)

  _setAuth: (@auth) -> return

  _pullHost: (rest) ->
    if ~(firstNonHost = rest.search(nonHostRegex))
      host = rest.substr(0, firstNonHost)
      rest = rest.substr(firstNonHost)
    else
      host = rest
      rest = ""

    @_setHost host
    return rest

  _setHost: (host) ->
    @hostname = host

    if port = portPattern.exec(host)
      port = port[0]
      @port = +port.substr(1) if port isnt ":"
      @hostname = host.substr(0, host.length - port.length)
    else
      delete @port

    @_setHostname @hostname
    return

  _setPort: (@port) ->
    @host = "#{@hostname}:#{@port}"
    return

  _setHostname: (@hostname) ->
    @hostname = "" if @hostname.length > hostnameMaxLen
    @hostname = @hostname.toLowerCase()
    @host = @hostname
    @host += ":#{@port}" if @port
    return

  _pullHash: (rest) ->
    return rest unless ~(hash = rest.indexOf("#"))
    @hash = rest.substr(hash)
    rest.slice(0, hash)

  _setHash: (@hash) ->
    delete @hash unless @hash
    return

  _pullQuery: (rest) ->
    @search = ""
    @query = {}

    return rest unless ~(qm = rest.indexOf("?"))
    @_setSearch rest.substr(qm)
    rest.slice(0, qm)

  _pullPathname: (rest) ->
    @pathname = rest
    @path = @pathname + @search
    return ''

  _setPath: (@path) ->
    if q = @path.indexOf('?')
      @pathname = @path.substr(0, q)
      @search = @path.substr(q)
      @query = querystring.parse(@search[1..])
    else
      @pathname = @path
      @search = ''
      @query = {}

    return

  _setPathname: (@pathname) ->
    @path = @pathname + @search
    return

  _setSearch: (@search) ->
    @path = @pathname + @search
    @query = querystring.parse(@search[1..])
    return

  _setQuery: (@query) ->
    @search = '?' + querystring.stringify(@query)
    @path = @pathname + @search
    return


  # Escapes RFC delims & chars that shouldn't appear in the URL (but does *not*
  # do an HTML escape -- assumes that's already been done)
  @escape: (str) -> str.replace(autoEscapeRegex, (char) -> autoEscapeRepl[char])

  format: ->
    href = ''
    href += @protocol if @protocol
    href += '//' if @slashes
    href += "#{@auth}@" if @auth
    href += @host if @host
    href += @path
    href += @hash if @hash
    @href = href

  constructor: (url='', defaults) ->
    @_build(url)
    @defaults defaults if defaults

  _build: (url) ->
    rest = Url.escape url.replace(nonAsciiRegex, '').trim()

    if proto = protocolPattern.exec(rest)
      @protocol = (proto = proto[0]).toLowerCase()
      rest = rest.substr(proto.length)
    
    if @slashes = rest.substr(0, 2) is "//"
      rest = rest.substr(2)

      rest = @_pullAuth rest
      rest = @_pullHost rest

    rest = @_pullHash rest
    rest = @_pullQuery rest

    @_pullPathname rest
    @href = @format()
    return this

  clone: -> new @constructor(@href)

  # changes the fields given in the obj and reformats the Url.
  # Because there's some redundancy in the parameters, parameters are applied
  # in this order, where nested parameters are not applied if the parent
  # parameter is present:
  #   href
  #     auth
  #     path
  #       search
  #         query
  #       pathname
  #     hash
  #     protocol
  #       slashes
  #     host
  #       hostname
  #       port
  # NOTE: the parameters must all be URL-encoded before being passed here
  # (except query; that's an object) including auth.
  reform: (obj) ->
    return @_build(url) if (url = obj.href)?

    @auth = Url.escape auth if (auth = obj.auth)?

    if (path = obj.path)?
      @_setPath Url.escape path
    else
      if (search = obj.search)?
        @_setSearch Url.escape search
      else if (query = obj.query)?
        @_setQuery query

      if (pathname = obj.pathname)?
        @_setPathname Url.escape pathname

    if (hash = obj.hash)?
      @_setHash Url.escape hash

    if (host = obj.host)?
      @_setHost Url.escape host
    else
      if (hostname = obj.hostname)?
        @_setHostname Url.escape hostname
      if (port = obj.port)?
        @_setPort port

    @href = @format()
    return this

  # adds any missing parameters using the values of the arg
  defaults: (rhs) ->
    udefaults(this, rhs)
    @slashes ||= rhs.slashes
    @href = @format()
    this

module.exports = Url

