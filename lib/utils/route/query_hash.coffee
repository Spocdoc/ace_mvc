querystring = require '../url/querystring'
empty = {}

class QueryHash
  constructor: (arg) ->
    @varNames = []

    if arg.charAt(0) is ':' and !~arg.indexOf('&')
      @varNames.push @name = arg.substr(1)
    else
      for k, v of @obj = querystring.parse arg
        @varNames.push @obj[k] = if v then v.substr(1) else k


  format: (outlets) ->
    try
      if @name
        if (value = outlets[@name].value)?
          querystring.stringifyValue outlets[@name].value
        else
          ""
      else if @obj
        obj = {}
        obj[k] = v for k,v of @obj when (v = outlets[v].value)?
        querystring.stringify obj
    catch _error

  setOutlets: (part, outlets) ->
    try
      if @name
        outlets[@name].set querystring.parseValue part
      else if @obj
        obj = querystring.parse(part) || empty
        outlets[v].set obj[k] for k,v of @obj
    catch _error
    return



module.exports = QueryHash
