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
          when '?' then (@query ||= new QueryHash).add arg.substr(1)
          when '#' then (@hash ||= new QueryHash).add arg.substr(1)

    @path ||= new Path '/'
    @path.outletHash = outletHash

    push = Array.prototype.push

    @varNames = {}

    @pathVarNames = {}
    @varNames[key.name] = @pathVarNames[key.name] = 1 for key in @path.keys
    @varNames[name] = @pathVarNames[name] = 1 for name of outletHash

    @otherVarNames = {}
    @varNames[name] = @otherVarNames[name] = 1 for name in @query.varNames if @query
    @varNames[name] = @otherVarNames[name] = 1 for name in @hash.varNames if @hash

    debug "Built route with path regex #{@path.regexp}"

  matchOutlets: (outlets) -> @path.matchOutlets outlets

  match: (url, outlets) ->
    return false unless @path.match url, outlets
    @query?.setOutlets url.search.substr(1), outlets
    @hash?.setOutlets url.hash?.substr(1), outlets
    outlet.set undefined for k,outlet of outlets when !@varNames[k]
    true

  format: (outlets) ->
    url = @path.format outlets
    url += "?#{query}" if query = @query?.format outlets
    url += "##{hash}" if hash = @hash?.format outlets
    url


module.exports = Route
