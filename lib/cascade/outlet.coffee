Cascade = require './cascade'
makeId = require '../id'
debug = global.debug 'ace:cascade'
debugError = global.debug 'ace:error'

# options:
#     silent    don't run the function immediately
#     value     initialize the value (eg, if the value parameter is a function; used with silent)
class Outlet extends Cascade
  @name = 'Outlet'
  @auto = undefined

  _setValue: (value, version) ->
    debug "_setValue #{@} to #{value}"
    if @_value is value and (!version? or @_version is version)
      @stopPropagation()
    else
      @_version = version || 0
      @_value = value
    return

  constructor: (init, options={}) ->
    @_eqFunc = undefined
    @_eqDefault = undefined
    @_eqOutlets = {}
    @_autoInflows = {}
    @_version = 0
    @auto = !!options.auto

    super (done) =>
      debug "#{@changes[0]?.constructor.name} [#{@changes[0]?.cid}] -> #{@constructor.name} [#{@cid}]"

      callDone = true
      returned = false

      for change in @changes
        if change is @_eqFunc or @_autoInflows[change.cid]
          found = @_eqFunc
          break
        found = @_eqOutlets[change.cid]

      found ||= @_eqDefault

      if typeof found is 'function'
        Cascade.Block =>
          @_autoContext = found.cid
          prev = Outlet.auto
          if @auto
            Outlet.auto = this
            @_autoInflows[k] = 0 for k of @_autoInflows
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
          catch _error
            debugError _error.stack if _error
          finally
            Outlet.auto = prev
            if @auto
              for k,v of @_autoInflows when !v
                @inflows[k].outflows.remove this
                delete @_autoInflows[k]
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

    debug "set #{options.silent && "(silently)" || ""} #{@constructor.name} [#{@cid}] to [#{value}]"

    ++@_runNumber
    @running = false
    outflow = false

    if typeof value is 'function'
      throw new Error("Can't set an outlet to more than one function at a time") if @_eqFunc
      value.cid ||= makeId()
      @_eqDefault = @_eqFunc = value

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
        @setThisPending true
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
      return unless @_eqFunc is value
      @inflows[cid].outflows.remove this for cid of @_autoInflows
      @_autoInflows = {}
      @_eqFunc = undefined
      @_resetDefault()

    else if value instanceof Cascade
      return unless @_eqOutlets[value.cid]
      delete @_eqOutlets[value.cid]
      @_resetDefault()
      @outflows.remove value
      value.unset? this

    else unless value?
      eqOutlets = @_eqOutlets
      @_eqOutlets = {}

      @inflows[cid].outflows.remove this for cid of @_autoInflows
      for cid,value of eqOutlets
        @outflows.remove value
        value.unset? this

      @_autoInflows = {}
      @_eqDefault = @_eqFunc = undefined

    return

  detach: (inflow) ->
    unless inflow?
      @_eqDefault = @_eqFunc = undefined
      @_eqOutlets = {}
      @_autoInflows = {}
    else if inflow is @_eqFunc
      @unset inflow
    else
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
    if @_autoInflows[inflow.cid]?
      @_autoInflows[inflow.cid] = 1
    else
      @_autoInflows[inflow.cid] = 1
      inflow.outflows.add this
      if inflow.pending and !@outflows[inflow.cid]
        debug "Aborting #{@} because new pending inflow"
        # then shouldn't run -- keep this pending but set @running to false
        ++@_runNumber
        @running = false
        throw 0
    return

  _resetDefault: ->
    (break) for cid,outlet of @_eqOutlets
    @_eqDefault = outlet

module.exports = Outlet
