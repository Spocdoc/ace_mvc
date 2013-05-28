Cascade = require './cascade'
makeId = require '../id'
require '../polyfill'
debug = global.debug 'ace:cascade'

# options:
#     silent    don't run the function immediately
#     value     initialize the value (eg, if the value parameter is a function; used with silent)
class Outlet extends Cascade
  @stack = []
  @stackLast = undefined

  @noAuto: (fn) ->
    ->
      Outlet.enterContext()
      try
        fn.apply(this, arguments)
      finally
        Outlet.exitContext()

  @enterContext: (ctx=null) ->
    @stack.push @stackLast
    @stackLast = ctx
    return

  @exitContext: ->
    @stackLast = @stack.pop()
    return

  enterContext: (@_autoContext) ->
    Outlet.enterContext this
    list = @_autoInflows[@_autoContext.cid] ||= {}
    list[k] = 0 for k of list

  exitContext: ->
    Outlet.exitContext()
    list = @_autoInflows[@_autoContext.cid] ||= {}
    for k,v of list when !v
      @inflows[k].outflows.remove this
      delete list[k]
    return

  _setValue: (value, version) ->
    debug "_setValue #{@} to #{value}"
    if @_value is value and (!version? or @_version is version)
      @stopPropagation()
    else
      @_version = version || 0
      @_value = value
    return

  _findFuncByChanges: ->
    for cid,fn of @_eqFuncs
      for change in @changes
        return fn if @_autoInflows[fn.cid][change.cid]?

  _pickSource: ->
    for change in @changes
      (return found) if found = @_eqOutlets[change.cid] || @_eqFuncs[change.cid]

    len = 0
    (break if ++len > 1) for k of @_eqFuncs
    switch len
      when 0
        for cid,outlet of @_eqOutlets
          return outlet
      when 1
        @_eqFuncs[k]
      else
        @_findFuncByChanges()

  constructor: (init, options={}) ->
    @_multiGet = undefined
    @_eqFuncs = {}
    @_eqOutlets = {}
    @_autoInflows = {}
    @_version = 0

    super (done) =>
      debug "#{@changes[0]?.constructor.name} [#{@changes[0]?.cid}] -> #{@constructor.name} [#{@cid}]"

      callDone = true
      returned = false

      found = @_pickSource()

      if typeof found is 'function'
        @enterContext found
        try
          if found.length > 0
            callDone = false
            num = @_runNumber
            found (value) =>
              @_setValue value if num is @_runNumber
              callDone = true
              done() if returned
              return
          else
            @_setValue found()
        finally
          @exitContext()

      else if found
        @_autoContext = undefined
        @_setValue found.get(), found._version

      returned = true
      done() if callDone
      return

    @set init, options

  get: ->
    out._autoInflow this if out = Outlet.stackLast

    if len = arguments.length
      if @_multiGet
        @_multiGet.get(arguments...)
      else if len is 1 and typeof @_value is 'object'
        @_value[arguments[0]]
      else
        @_value
    else
      @_value

  set: (value, options={}) ->
    return if @_value is value

    debug "set #{@constructor.name} [#{@cid}] to [#{value}]"

    ++@_runNumber
    outflow = false

    if typeof value is 'function'
      value.cid ||= makeId()
      return if @_eqFuncs[value.cid]

      @_eqFuncs[value.cid] = value

    else if typeof value?.get is 'function'
      value.cid ||= makeId()
      return if @_eqOutlets[value.cid]

      @_multiGet = value if value.get.length > 0
      @_eqOutlets[value.cid] = value

      if typeof value.set is 'function'
        value.set this, silent: true
      else if value.outflows
        value.outflows.add this

      outflow = true

    else
      @_version = 0
      @_value = value

    unless options.silent
      if value is @_value then @cascade() else @run value

    @outflows.add value if outflow
    return

  # call when the object value has been modified in place
  modified: do ->
    version = 0
    ->
      @_version = ++version
      @cascade()
      return

  unset: (value) ->
    if typeof value is 'function'
      delete @_eqFuncs[value.cid]
      delete @_autoInflows[value.cid]

    else if typeof value?.get is 'function'
      return unless @_eqOutlets[value.cid]
      delete @_eqOutlets[value.cid]
      delete @_autoInflows[value.cid]
      @_resetMultiget() if @_multiGet is value
      @outflows.remove value
      value.unset this

    else unless value?
      @_multiGet = undefined
      @_eqFuncs = {}
      @unset value for cid,value of @_eqOutlets

    return

  detach: (inflow) ->
    unless inflow?
      @_eqFuncs = {}
      @_eqOutlets = {}
      @_multiGet = undefined
      @_autoInflows = {}
    else if inflow.cid
      delete @_autoInflows[inflow.cid]
      if typeof inflow is 'function'
        delete @_eqFuncs[inflow.cid]
      else if typeof inflow?.get is 'function'
        delete @_eqOutlets[inflow.cid]
        @_resetMultiget() if @_multiGet is inflow
    super

  toJSON: -> @_value

  toString: -> "#{@constructor.name} [#{@cid}] value [#{@_value}]"

  # include array methods. note that all of these are preserved in closure compiler
  for method in ['length', 'join', 'concat', 'slice']
    @prototype[method] = do (method) -> ->
      Array.prototype[method].apply(@_value, arguments)

  for method in ['push', 'pop', 'reverse', 'shift', 'unshift', 'splice', 'sort']
    @prototype[method] = do (method) -> ->
      ret = Array.prototype[method].apply(@_value, arguments)
      @modified()
      ret

  inc: (delta) -> @set(@_value + delta)

  _resetMultiget: ->
    @_multiGet = undefined
    break for cid,o of @_eqOutlets when o.get.length > 0 and @_multiGet = o
    return

  _autoInflow: (inflow) ->
    return unless @_autoContext
    list = @_autoInflows[@_autoContext.cid]
    inflow.outflows.add this unless list[inflow.cid]?
    list[inflow.cid] = 1
    return

module.exports = Outlet
