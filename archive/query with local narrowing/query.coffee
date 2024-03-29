Outlet = require 'outlet'
OJSON = require 'ojson'
queryCompile = require './query_compile'
{makeId} = require 'lodash-fork'
NavCache = require 'navigate-fork/cache'
emptyArray = []
debug = global.debug "ace:mvc:query"

hash = (obj) -> ''+obj

arraysDiffer = (lhs, rhs) ->
  return true if lhs.length isnt rhs.length
  for entry, i in rhs
    return true if lhs[i] isnt entry
  false

arrayIsSubset = (sup, sub) ->
  sup = sup.concat().sort()
  sub = sub.concat().sort()
  `for (var i = 0, iE = sup.length, j = 0, jE = sub.length; i < iE && j < jE; ++i) {
    if (sup[i] > sub[j]) return false;
    if (sup[i] == sub[j]) ++j;
  }`
  j is sub.length

CACHE_READ = 1
CACHE_WRITE = 2

module.exports = class Query
  @useBootCache = 2 # default on server

  constructor: (@Model, @_spec={}, limit, sort) ->
    @['limit'] = @limit = new Outlet limit ? 20
    @['sort'] = @sort = new Outlet sort
    @['pending'] = @pending = new Outlet false
    @['error'] = @error = new Outlet
    @['results'] = @results = new Outlet []
    @navCache = new NavCache

    @_hash = hash @_ojSpec = OJSON.toOJSON @_spec
    @_readBootCache() if Query.useBootCache & CACHE_READ

    @_clientVersion = 0
    @_updater = new Outlet =>
      @_hash = hash @_ojSpec = OJSON.toOJSON @_spec

      if Query.useBootCache & CACHE_READ
        @_readBootCache()
      else if results = @navCache.get @_hash
        @_updateResults results

      if @limit.value < 1
        @_updateResults [] if @results.value.length
        delete @_func
      else
        @_compile()

        unless @_subquery && (results = @_narrowLocally @results.value) && (@_full || @limit.value is 1)
           ++@_clientVersion
           unless @pending.value
            if @limit.value is 1
                @_findOne()
              else
                @_update()
        @_updateResults results if results
      return makeId() # to trigger the 'distinct' calls

    @_initOutlets @_spec

  _readBootCache: ->
    if ids = @Model.queryCache[@_hash]?.ids
      results = []
      results[i] = @Model.read id for id, i in ids
      @_updateResults results
    return

  _update: ->
    @pending.set true
    @_serverVersion = @_clientVersion

    @Model.prototype.sock.emit 'read', @Model.prototype.aceType, null, null, @_ojSpec, @limit.value, @sort.value, (code, docs) =>
      pending = false
      Outlet.openBlock()
      if code is 'd'
        @error.set ''
        results = []
        results[i] = @Model.read id for id, i in docs
        @_full = results.length < @limit.value
        if @_clientVersion != @_serverVersion
          results = if @_subquery then @_narrowLocally(results) else 0
          @_update() if pending = !@_subquery or !@_full
        if results
          @_subquery = 1
          @_updateResults results
      else if pending = (@_clientVersion != @_serverVersion and !@_subquery)
        @_update()
      else
        @error.set docs || "can't read"
        @_full = 1
        @_updateResults []
      @pending.set pending
      Outlet.closeBlock()
      return
    return

  _findOne: ->
    return if (model = @results.value?[0]) and @_func model
    for id, model of @Model.models when @_func model
      @_serverVersion = @_clientVersion
      @_updateResults [model]
      return
    @_update()
    return

  _narrowLocally: (orig) ->
    results = []; i = 0
    (result[i++] = model if @_func model) for model in orig
    results

  _updateResults: (results) ->
    if Query.useBootCache & CACHE_WRITE
      idResults = []
      idResults[i] = model.id for model,i in results
      (@Model.queryCache[@_hash] ||= {}).ids = idResults

    @navCache.set @_hash, results

    if arraysDiffer results, @results.value
      Outlet.openBlock()
      @results.set results
      outlet.set results[i] for i, outlet of @_peggedResults
      Outlet.closeBlock()

    return

  'result': (n) ->
    (@_peggedResults ||= {})[n] ||= new Outlet @results.value[n]

  'refresh': ->
    unless @pending.value
      @_updater.set makeId()
      @_update() if @limit.value > 0
    return

  _compile: -> @_func = queryCompile @_spec

  # analogous to RegExp.exec -- returns truthy if matches
  exec: (model) -> (@_func ||= @_compile())(model)

  _outletOutflowArray: (oldValue, outlet, inverted) ->
    =>
      @_subquery &&= inverted ^ arrayIsSubset(oldValue, outlet.value)
      oldValue = outlet.value

  _outletOutflowMath: (oldValue, outlet, inverted, math) ->
    =>
      if typeof oldValue is 'number' and typeof outlet.value is 'number'
        @_subquery &&= inverted ^ (if math.charAt(1) is 'g' then outlet.value >= oldValue else outlet.value <= oldValue)
      else
        @_subquery = false
      oldValue = outlet.value

  _outletOutflowNone: (outlet) ->
    =>
      @_subquery = false
      outlet.value

  _initOutlets: (obj, inverted_) ->
    for k, outlet of obj
      inverted = inverted_ or (k in ['$not','$nin','$nor','$ne'])
      math = k if k in ['$gte','$lte','$gt','$lt']
      
      if outlet instanceof Outlet
        oldValue = outlet.value

        if Array.isArray oldValue
          outflow = @_outletOutflowArray oldValue, outlet, inverted

        else if math
          outflow = @_outletOutflowMath oldValue, outlet, inverted, math

        else
          outflow = @_outletOutflowNone outlet

        outlet.addOutflow outflow = new Outlet outflow
        outflow.addOutflow @_updater

      else
        @_initOutlets outlet, inverted, math

    return

  # returns an outlet that contains an array of the unique values for the given
  # field across all the documents matching the query (server side)
  'distinct': (key) ->
    return outlet if outlet = (@_distinct ||= {})[key]
    @_distinct[key] = outlet = new Outlet ((Query.useBootCache & CACHE_READ) && @Model.queryCache[@_hash]?.distinct?[key]) || emptyArray

    navCache = new NavCache
    serverVersion = pending = 0
    @_updater.addOutflow new Outlet distinctUpdater = =>
      unless pending
        pending = true
        serverVersion = @_clientVersion

        if (Query.useBootCache & CACHE_READ) and cached = @Model.queryCache[@_hash]?.distinct?[key]
          outlet.set cached
        else if cached = navCache.get @_hash
          outlet.set cached

        @Model.prototype.sock.emit 'distinct', @Model.prototype.aceType, @_ojSpec, key, (code, docs) =>
          pending = false
          if code is 'd'
            docs = OJSON.fromOJSON docs
          else
            docs = emptyArray
          outlet.set docs if !outlet.value or arraysDiffer outlet.value, docs
          unless serverVersion is @_clientVersion
            distinctUpdater()
          else if Query.useBootCache & CACHE_WRITE
            ((@Model.queryCache[@_hash] ||= {}).distinct ||= {})[key] = docs
          return
      return
    outlet


require('./query_client')(Query)
