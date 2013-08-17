querystring = require '../url/querystring'
empty = {}

class QueryHash
  constructor: (arg) ->
    @varNames = []
    @obj = []
    @add arg if arg

  add: (arg) ->
    for k, v of querystring.parse arg, true
      k = k.substr(1) unless v
      @varNames.push @obj[k] = if v then v.substr(1) else k
    return

  format: (outlets) ->
    try
      obj = {}
      obj[k] = v for k,v of @obj when (v = outlets[v].value)?
      querystring.stringify obj
    catch _error

  setOutlets: (part, outlets) ->
    try
      obj = querystring.parse(part) || empty
      outlets[v].set obj[k] for k,v of @obj
    catch _error
    return



module.exports = QueryHash
