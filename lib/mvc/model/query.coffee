Outlet = require '../../utils/outlet'
OJSON = require '../../utils/ojson'
queryCompile = require './query_compile'
makeId = require '../../utils/id'

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
  @useCache = 0

  constructor: (@Model, @_spec={}, limit, sort) ->
    @['limit'] = @limit = new Outlet limit || 20
    @['sort'] = @sort = new Outlet sort
    @['pending'] = @pending = new Outlet false
    @['error'] = @error = new Outlet
    @['results'] = @results = new Outlet []

    @_useCache() if Query.useCache & CACHE_READ

    @_clientVersion = 0
    @_updater = new Outlet =>
      @_useCache() if Query.useCache

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

  _useCache: ->
    @_hash = OJSON.stringify @_spec
    if (Query.useCache & CACHE_READ) and ids = @Model.queryCache[@_hash]
      results = []
      results[i] = @Model.read id for id, i in ids
      @_updateResults results
    return

  _update: ->
    @pending.set true
    @_serverVersion = @_clientVersion

    @Model.prototype.sock.emit 'read', @Model.prototype.coll, null, null, OJSON.toOJSON(@_spec), @limit.value, @sort.value, (code, docs) =>
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
    if Query.useCache & CACHE_WRITE
      idResults = []
      idResults[i] = model.id for model,i in results
      @Model.queryCache[@_hash] = idResults

    Outlet.openBlock()
    @results.set results
    outlet.set results[i] for i, outlet of @_peggedResults
    Outlet.closeBlock()
    return

  'result': (n) ->
    (@_peggedResults ||= {})[n] ||= new Outlet @results.value[n]

  'refresh': ->
    @_update() unless @pending.value
    return

  _compile: -> @_func = queryCompile @_spec

  # analogous to RegExp.exec -- returns truthy if matches
  exec: (model) -> (@_func ||= @_compile())(model)

  get: (key) ->
    [path...,key] = split key '.'

    inverted = false
    math = undefined

    obj = @_spec
    for k in path
      inverted ||= k in ['$not','$nin','$nor','$ne']
      math = k if k in ['$gte','$lte','$gt','$lt']
      obj = obj[k]

    oldValue = obj[key]
    outlet = new Outlet oldValue

    if Array.isArray obj[key]
      outflow = =>
        @_isSubquery &&= inverted ^ arrayIsSubset(oldValue, outlet.value)
        oldValue = outlet.value

    else if math and typeof obj[key] is number
      if math.charAt(1) is 'g'
        outflow = =>
          @_isSubquery &&= inverted ^ (outlet.value >= oldValue)
          oldValue = outlet.value
      else
        outflow = =>
          @_isSubquery &&= inverted ^ (outlet.value <= oldValue)
          oldValue = outlet.value

    outflow ||= =>
      @_isSubquery = false
      outlet.value

    outlet.addOutflow outflow = new Outlet outflow
    outflow.addOutflow @_updater
    outlet

  # returns an outlet that contains an array of the unique values for the given
  # field across all the documents matching the query (server side)
  'distinct': (key) ->
    return outlet if outlet = (@_distinct ||= {})[key]
    @_distinct[key] = outlet = new Outlet empty = []
    serverVersion = pending = 0
    @_updater.addOutflow new Outlet distinctUpdater = =>
      unless pending
        pending = true
        serverVersion = @_clientVersion
        @Model.prototype.sock.emit 'distinct', @Model.prototype.coll, OJSON.toOJSON(@_spec), key, (code, docs) =>
          pending = false
          outlet.set if code is 'd' then docs else empty
          distinctUpdater() unless serverVersion is @_clientVersion
          return
      return
    outlet

