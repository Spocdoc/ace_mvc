querystring = require 'uri-fork/querystring'
empty = {}

module.exports = class QueryHash
  constructor: (arg) ->
    @obj = []
    @add arg if arg

  add: (arg) ->
    for k, v of querystring.parse arg, true
      k = k.substr(1) unless v
      @obj[k] = if v then v.substr(1) else k
    return

  format: (outlets) ->
    try
      obj = {}
      # any "falsy" value is omitted
      obj[k] = v for k,v of @obj when v = outlets[v].value
      querystring.stringify obj
    catch _error

  setOutlets: (part, outlets) ->
    try
      obj = querystring.parse(part) || empty
      outlets[v].set obj[k] for k,v of @obj # when !(ou = outlets[v]).pending # NOTE: now that the outlets run the function even when set, it should be OK to assign the value from the route even if there's a pending function call. this allows the scroll position storage to work
    catch _error
    return

