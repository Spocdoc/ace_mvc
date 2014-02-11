{defaults} = require 'lodash-fork'
Path = require './path'
QueryHash = require './query_hash'
Outlet = require 'outlet'
debug = global.debug 'ace:routing'

# similar to express
module.exports = class Route
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
          else @name = arg

    @pathNames = {}

    if @path
      if outletHash
        @path.outletHash = outletHash
        @pathNames[name] = 1 for name of outletHash
      @pathNames[name] = 1 for name in @path.keys

    debug "Built route with path regex #{@path.regexp}" if @path

  matchOutlets: (outlets) ->
    @path.matchOutlets outlets

  match: (uri, outlets) ->
    return false unless @path.match uri, outlets
    @query?.setOutlets uri.search.substr(1), outlets
    @hash?.setOutlets uri.hash.substr(1), outlets
    true

  format: (outlets) ->
    uri = @path.format outlets
    uri += "?#{query}" if query = @query?.format outlets
    uri += "##{hash}" if hash = @hash?.format outlets
    uri

