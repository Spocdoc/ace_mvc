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
autoEscapeRepl[c] = escape(c) for c in autoEscape
autoEscapeRegex = new RegExp("[#{RegExp.escape(autoEscape.join())}]",'g')

dupSlashesRegex = /\/+/g

class Url
  _pullAuth: (rest) ->
    return rest unless ~(atSign = rest.indexOf("@"))
    auth = rest.slice(0, atSign)
    (return rest if ~auth.indexOf(c)) for c in nonAuthChars
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
    if !host
      delete @port
      delete @host
      delete @hostname
      delete @protocol
      @slashes = false
      return

    @slashes = true
    @hostname = host

    if port = portPattern.exec(host)
      port = port[0]
      @port = +port.substr(1) if port isnt ":"
      @hostname = host.substr(0, host.length - port.length)
    else
      delete @port

    @_setHostname @hostname
    return

  _setPort: (port) ->
    if port?
      @port = port
      @host = "#{@hostname}:#{@port}"
    else
      delete @port
      @host = @hostname if @hostname?
    return

  _setHostname: (@hostname) ->
    if !hostname
      @_setHost()
      return
    hostname = "" if hostname.length > hostnameMaxLen
    @host = @hostname = hostname.toLowerCase()
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
    @pathname = rest.replace dupSlashesRegex, '/'
    @path = @pathname + @search
    return ''

  _setPath: (path) ->
    if ~(q = path.indexOf('?'))
      @search = path.substr(q)
      @query = querystring.parse(@search[1..])
      @_setPathname path.substr(0, q)
    else
      @search = ''
      @query = {}
      @_setPathname path
    return

  _setPathname: (pathname) ->
    @pathname = pathname.replace dupSlashesRegex, '/'
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

  _setProtocol: (protocol) ->
    if !protocol
      return unless @protocol
      delete @protocol
    else
      @protocol = protocol
      @slashes = true
    return

  # Escapes RFC delims & chars that shouldn't appear in the URL (but does *not*
  # do an HTML escape -- assumes that's already been done)
  @escape: (str) -> str.replace(autoEscapeRegex, (c) -> autoEscapeRepl[c])

  format: ->
    href = ''
    href += @protocol if @protocol
    href += '//' if @slashes
    href += "#{@auth}@" if @auth
    href += @host if @host
    href += @path
    href += @hash if @hash
    @href = href

  toString: -> @href

  constructor: (url='', defaults) ->
    @defaults defaults if defaults
    @_build(url)

  _build: (url) ->
    rest = Url.escape url.replace(nonAsciiRegex, '').trim()

    if proto = protocolPattern.exec(rest)
      @protocol = (proto = proto[0]).toLowerCase()
      rest = rest.substr(proto.length)
    
    if slashes = rest.substr(0, 2) is "//"
      if @slashes is false and rest == url
        rest = rest.substr(1)
      else
        @slashes = true
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

    if {}.hasOwnProperty.call(obj, 'hash')
      @_setHash(obj.hash && Url.escape obj.hash)

    if {}.hasOwnProperty.call(obj, 'protocol')
      @_setProtocol(obj.protocol)

    if {}.hasOwnProperty.call(obj, 'host')
      @_setHost(obj.host && Url.escape obj.host)
    else
      if {}.hasOwnProperty.call(obj, 'hostname')
        @_setHostname(obj.hostname && Url.escape obj.hostname)
      if {}.hasOwnProperty.call(obj, 'port')
        @_setPort obj.port

    @href = @format()
    return this

  # adds any missing parameters using the values of the arg
  defaults: (rhs) ->
    udefaults(this, rhs)
    @slashes ||= rhs.slashes if rhs.slashes?
    @href = @format()
    this

module.exports = Url

