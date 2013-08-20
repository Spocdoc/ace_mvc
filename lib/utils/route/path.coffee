parseRoute = require './parse_route'

module.exports = class Path
  constructor: (path) ->
    @keys = []
    [@regexp, @format] = parseRoute path, @keys

  matchOutlets: (outlets) ->
    for key in @keys when !key.optional
      return false unless outlets[key.name].value
    for k,v of @outletHash
      return false unless outlets[k].value is v
    return true

  match: (url, outlets) ->
    if m = @regexp.exec url.pathname
      
      for val, i in m[1..] when (key = @keys[i]) and ou = outlets[key.name]
        try
          val = decodeURIComponent(val) if typeof val is 'string'
        catch _error
          val = undefined

        ou.set val

      outlets[k].set v for k,v of @outletHash

      true

    else
      false
