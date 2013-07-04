queryCompile = require './query_compile'

module.exports = (pkg) ->

  Outlet = pkg.cascade.Outlet
  OJSON = pkg.ojson || require('../../utils/ojson')(pkg)
  sock = pkg.mvc.sock

  arrayIsSubset = (sup, sub) ->
    sup = sup.concat().sort()
    sub = sub.concat().sort()
    `for (var i = 0, iE = sup.length, j = 0, jE = sub.length; i < iE && j < jE; ++i) {
      if (sup[i] > sub[j]) return false;
      if (sup[i] == sub[j]) ++j;
    }`
    j is sub.length

  pkg.mvc.Query = class Query
    constructor: (@Model, @_spec={}, sort, limit) ->
      @['sort'] = @sort = new Outlet sort
      @['limit'] = @limit = new Outlet limit || 20
      @['pending'] = @pending = new Outlet false
      @['error'] = @error = new Outlet
      @['results'] = @results = new Outlet []
      @_serverVersion = @_clientVersion = 0
      @_isSubquery = false
      @_results = []
      @_updater = new Outlet => @_update()

    _update: ->
      isSubquery = @_isSubquery
      @_isSubquery = true

      if @_isFull and isSubquery
        @_serverVersion = @_clientVersion
        @_narrowLocally()
        @pending.set false
      else
        clientVersion = @_clientVersion
        @pending.set pending = @_serverVersion != clientVersion

        if pending
          sock.emit 'read',
            'c': @Model.coll
            'q': OJSON.toOJSON @spec
            'l': @limit.value
            's': @sort.value
            (reply) =>
              @_serverVersion = clientVersion
              finished = clientVersion is @_clientVersion

              type = reply?[0]
              @error.set reply[1] || "Can't execute query" if type is 'rej'

              if @_isFull = (finished || isSubquery)
                if type is 'doc'
                  @_results = []
                  @_results[i] = @Model.read id for id, i in reply[1]
                  @_isFull = @_results.length < @limit.value
                  @_narrowLocally() unless finished
                  @_updateResults()
                else
                  @_serverVersion = @_clientVersion
                  @_results = []
                  @_updateResults()

              @_update() unless @_isFull or finished

    _narrowLocally: ->
      results = []; i = 0
      (results[i++] = model if @_func model) for model in @_results
      @_results = results

    _updateResults: -> @results.set @_results

    _compile: -> @_func = queryCompile @_spec

    # analogous to RegExp.exec -- returns truthy if matches
    exec: (model) -> (@_func ||= @_compile())(model)

    'refresh': ->
      unless @pending.value
        @_isFull = false
        @_update()
      return

    get: (key) ->
      [path...,key] = split key '.'

      inverted = false
      math = undefined

      obj = @spec
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

      outlet.outflows.add outflow = new Outlet outflow
      outflow.outflows.add @_updater
      outlet


    # returns an outlet that contains an array of the unique values for the given
    # field across all the documents matching the query (server side)
    unique: (key) ->



