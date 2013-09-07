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
      ou.set obj[k] unless (ou = outlets[v]).pending for k,v of @obj
    catch _error
    return
