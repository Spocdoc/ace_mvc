parseRoute = require './parse_route'

module.exports = class Path
  constructor: (path) ->
    @keys = []
    @optional = []
    @required = []
    [@regexp, @format] = parseRoute path, @keys, @optional, @required
    @varNames = @optional.concat(@required)

  setOutletHash: (outletHash) ->
    @outletHash = outletHash
    @varNames.push Object.keys(outletHash)...
    return

  matchOutlets: (outlets) ->
    for key in @required
      return false unless outlets[key].value
    for k,v of @outletHash
      return false unless outlets[k].value is v
    true

  match: (url, outlets) ->
    if m = @regexp.exec url.pathname
      
      for val, i in m[1..] when (key = @keys[i]) and ou = outlets[key]
        try
          val = decodeURIComponent(val) if typeof val is 'string'
        catch _error
          val = undefined

        ou.set val

      outlets[k].set v for k,v of @outletHash

      true

    else
      false
