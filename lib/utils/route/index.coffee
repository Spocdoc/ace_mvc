{defaults} = require '../mixin'
Path = require './path'
QueryHash = require './query_hash'
debug = global.debug 'ace:routing'

# similar to express
class Route
  constructor: ->
    outletHash = undefined
    for arg in arguments
      if typeof arg is 'object'
        outletHash = arg
      else
        switch c = arg.charAt(0)
          when '/' then @path = new Path arg
          when '?' then @query = new QueryHash arg.substr(1)
          when '#' then @hash = new QueryHash arg.substr(1)

    @path ||= new Path '/'
    @path.outletHash = outletHash

    push = Array.prototype.push

    @pathVarNames = {}
    @pathVarNames[key.name] = 1 for key in @path.keys
    @pathVarNames[name] = 1 for name of outletHash

    @otherVarNames = {}
    @otherVarNames[name] = 1 for name in @query.varNames if @query
    @otherVarNames[name] = 1 for name in @hash.varNames if @hash

    @varNames = {}
    @varNames[k] = 1 for k of @pathVarNames
    @varNames[k] = 1 for k of @otherVarNames

    debug "Built route with path regex #{@path.regexp}"

  matchOutlets: (outlets) -> @path.matchOutlets outlets

  match: (url, outlets) ->
    return false unless @path.match url, outlets
    @query?.apply search.substr(1), outlets if search = url.search
    @hash?.apply hash.substr(1), outlets if hash = url.hash
    outlet.set undefined for k,outlet of outlets when !@varNames[k]
    true

  format: (outlets) ->
    url = @path.format outlets
    url += "?#{query}" if query = @query?.format outlets
    url += "##{hash}" if hash = @hash?.format outlets
    url


module.exports = Route
