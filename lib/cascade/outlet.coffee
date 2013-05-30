Cascade = require './cascade'
makeId = require '../id'
require '../polyfill'
debug = global.debug 'ace:cascade'

# options:
#     silent    don't run the function immediately
#     value     initialize the value (eg, if the value parameter is a function; used with silent)
class Outlet extends Cascade
  @auto = undefined

  enterContext: (@_autoContext) ->
    return

  exitContext: ->
    Outlet.auto = @_auto
    if @auto
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
    @_eqFuncs = {}
    @_eqOutlets = {}
    @_autoInflows = {}
    @_version = 0
    @auto = !!options.auto

    super (done) =>
      debug "#{@changes[0]?.constructor.name} [#{@changes[0]?.cid}] -> #{@constructor.name} [#{@cid}]"

      callDone = true
      returned = false

      for change in @changes
        (break) if found = @_eqOutlets[change.cid] || @_eqFuncs[change.cid]

      found ||= @_pickSource()

      if typeof found is 'function'
        Cascade.Block =>
          @_autoContext = found.cid
          prev = Outlet.auto
          if @auto
            Outlet.auto = this
            for k of (@_autoInflow = @_autoInflows[found.cid] ||= {})
              @_autoInflow[k] = 0
          else
            Outlet.auto = null

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
            Outlet.auto = prev
            if @auto
              for k,v of @_autoInflow when !v
                @inflows[k].outflows.remove this
                delete @_autoInflow[k]
                debug "Removing auto inflow #{k} from #{@}"

      else if found
        prev = Outlet.auto; Outlet.auto = null
        @_setValue found.get(), found._version
        Outlet.auto = prev

      returned = true
      done() if callDone
      return

    options.init = true
    @set init, options

  cascade: ->
    prev = Outlet.auto; Outlet.auto = null
    Cascade.prototype.cascade.call this
    Outlet.auto = prev
    return

  get: ->
    Outlet.auto?._addAuto this
    
    if @_value and len = arguments.length
      if @_value.get?.length > 0
        return @_value.get(arguments...)
      else if len is 1 and typeof @_value is 'object'
        return @_value[arguments[0]]

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

    else if value instanceof Cascade
      value.cid ||= makeId()
      return if @_eqOutlets[value.cid]

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
      if value is @_value
        @cascade() unless options.init
      else if options.init
        @pending = true
        @_run value
      else
        @run value

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
      @outflows.remove value
      value.unset? this

    else unless value?
      @_eqFuncs = {}
      @unset value for cid,value of @_eqOutlets

    return

  detach: (inflow) ->
    unless inflow?
      @_eqFuncs = {}
      @_eqOutlets = {}
      @_autoInflows = {}
    else if inflow.cid
      delete @_autoInflows[inflow.cid]
      if typeof inflow is 'function'
        delete @_eqFuncs[inflow.cid]
      else if typeof inflow?.get is 'function'
        delete @_eqOutlets[inflow.cid]
    super

  toJSON: -> @_value

  toString: -> "#{@constructor.name}#{if @auto then "/auto" else ""} [#{@cid}] value [#{@_value}]"

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

  _addAuto: (inflow) ->
    debug "Adding auto inflow #{inflow} to #{@}"
    inflow.outflows.add this unless @_autoInflow[inflow.cid]?
    @_autoInflow[inflow.cid] = 1
    return

module.exports = Outlet
