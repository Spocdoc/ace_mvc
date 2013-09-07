parseRoute = require './parse_route'

module.exports = class Path
  constructor: (path) ->
    @keys = []
    @optional = []
    @required = []
    [@regexp, @_shouldReplace, @format] = parseRoute path, @keys, @optional, @required

  shouldReplace: (oldPath, newPath) ->
    @_shouldReplace.test "#{newPath}##{oldPath}"

  matchOutlets: (outlets) ->
    for key in @required
      return false unless outlets[key].value
    for k,v of @outletHash
      return false unless outlets[k].value is v
    true

  match: (uri, outlets) ->
    if m = @regexp.exec uri.pathname
      
      for val, i in m[1..] when (key = @keys[i]) and ou = outlets[key]
        try
          val = decodeURIComponent(val) if typeof val is 'string'
        catch _error
          val = undefined

        ou.set val unless ou.pending

      outlets[k].set v for k,v of @outletHash

      true

    else
      false

