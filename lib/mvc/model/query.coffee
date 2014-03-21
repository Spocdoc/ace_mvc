Outlet = require 'outlet'
{makeId} = require 'lodash-fork'
NavCache = require 'navigate-fork/cache'
OJSON = require 'ojson'
emptyArray = []
_ = require 'lodash-fork'
debug = global.debug "ace:mvc:query"

hash = (obj) ->
  obj = OJSON.toOJSON obj

  str = "{"
  for k in Object.keys(obj).sort()
    v = obj[k]
    str += _.quote(k) + ":"
    if !v?
      str += 'null'
    else if v.constructor is String
      str += _.quote v
    else if typeof v is 'object'
      str += hash v
    else
      str += ''+v
  str + "}"

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

    @_hash = hash @_spec
    @_readBootCache() if Query.useBootCache & CACHE_READ

    @_clientVersion = 0
    @_updater = new Outlet =>
      @_hash = hash @_spec

      if Query.useBootCache & CACHE_READ
        @_readBootCache()
      else if results = @navCache.get @_hash
        @_updateResults results

      if @limit.value < 1
        @_updateResults [] if @results.value.length
      else
        ++@_clientVersion
        unless @pending.value
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

    @Model.prototype.sock.emit 'read', @Model.prototype.aceType, null, null, @_spec, @limit.value, @sort.value, (err, docs) =>
      if @_clientVersion != @_serverVersion
        @_update()
      else
        @pending.set false
        results = []
        @error.set(if err? then err.code || 'UNKNOWN' else '')
        results[i] = @Model.read id for id, i in docs if !err? and docs
        @_updateResults results
      return

  _updateResults: (results) ->
    if Query.useBootCache & CACHE_WRITE
      idResults = []
      idResults[i] = model.id for model,i in results
      (@Model.queryCache[@_hash] ||= {}).ids = idResults

    @navCache.set @_hash, results

    if arraysDiffer results, @results.value
      Outlet.openBlock()
      try
        @results.set results
        outlet.set results[i] for i, outlet of @_peggedResults
      finally
        Outlet.closeBlock()

    return

  'result': (n) ->
    (@_peggedResults ||= {})[n] ||= new Outlet @results.value[n]

  'refresh': ->
    unless @pending.value
      @_updater.set makeId()
      @_update() if @limit.value > 0
    return

  _initOutlets: (obj) ->
    for k, outlet of obj
      if outlet instanceof Outlet
        outlet.addOutflow @_updater
      else
        @_initOutlets outlet
    return

  # returns an outlet that contains an array of the unique values for the given
  # field across all the documents matching the query (server side)
  'distinct': (key) ->
    return outlet if outlet = (@_distinct ||= {})[key]
    @_distinct[key] = outlet = new Outlet ((Query.useBootCache & CACHE_READ) && @Model.queryCache[@_hash]?.distinct?[key])

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

        @Model.prototype.sock.emit 'distinct', @Model.prototype.aceType, @_spec, key, (err, docs) =>
          pending = false
          docs ||= emptyArray
          outlet.set docs if !outlet.value or arraysDiffer outlet.value, docs
          unless serverVersion is @_clientVersion
            distinctUpdater()
          else if Query.useBootCache & CACHE_WRITE
            ((@Model.queryCache[@_hash] ||= {}).distinct ||= {})[key] = docs
          return
      return
    outlet


require('./query_client')(Query)
