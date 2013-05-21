Cascade = require './cascade'

# options:
#     silent    don't run the function immediately
#     value     initialize the value (eg, if the value parameter is a function; used with silent)
class Outlet extends Cascade
  @stack = []
  @stackLast = undefined

  # ordinarily, outlets automatically add outflows to any outlet that's
  # retrieved in the current outlet's function. when this is unwanted,
  # execute the function in a new Outlet.context
  @context: (fn, ctx=null) ->
    @enterContext ctx
    try
      fn()
    finally
      @exitContext()

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

  context: (fn) -> Outlet.context(fn, this)

  constructor: (value, options={}) ->
    @_multiGet = undefined
    @_eqFuncs = {}
    @_eqOutlets = {}
    @_autoInflows = {}

    super (done) =>
      debugger if @cid is 'Cascade-1'
      (break if found = @_eqOutlets[change.cid] || @_eqFuncs[change.cid]) for change in @changes

      callDone = false

      if typeof found is 'function'
        @enterContext found
        try
          if found.length > 0
            num = @_calculateNum
            found (value) =>
              if num is @_calculateNum
                @stopPropagation() if @_value is value
                @_value = value
              done()
          else
            @stopPropagation() if @_value is (value = found())
            @_value = value
            callDone = true
        finally
          @exitContext()

      else if found
        @_autoContext = undefined
        @stopPropagation() if @_value is (value = found.get())
        @_value = value
        callDone = true

      else
        value = undefined
        returned = false
        num = @_calculateNum
        next = =>
          if num is @_calculateNum
            @stopPropagation() if @_value is value
            @_value = value
          callDone = true
          done() if returned
          return

        count = 0

        for cid,fn of @_eqFuncs
          ++count

          @enterContext fn
          try
            if fn.length > 0
              fn (result) =>
                value = result
                next() unless --count
            else
              value = fn()
              next() unless --count
          finally
            @exitContext()

        returned = true

      done() if callDone
      return

    @set value, options

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
    if value != @_value
      @_value = options.value if {}.hasOwnProperty.call(options, 'value')

      if typeof value is 'function'
        value.cid ||= Cascade.id()
        return @_value if @_eqFuncs[value.cid]

        @_eqFuncs[value.cid] = value
        @run value unless options.silent

      else if typeof value?.get is 'function'
        value.cid ||= Cascade.id()
        return @_value if @_eqOutlets[value.cid]

        @_multiGet = value if value.get.length > 0
        @_eqOutlets[value.cid] = value
        @run value unless options.silent
        @outflows.add value
        value.set this, silent: true if typeof value.set is 'function'

      else
        @_value = value
        @_calculateNum = (@_calculateNum || 0) + 1 # pretend the function was just re-run to get this value
        @cascade() unless options.silent

    return @_value

  unset: (value) ->
    if typeof value is 'function'
      delete @_eqFuncs[value.cid]

    else if typeof value?.get is 'function'
      return unless @_eqOutlets[value.cid]
      delete @_eqOutlets[value.cid]
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
    else if inflow.cid
      if typeof inflow is 'function'
        delete @_eqFuncs[inflow.cid]
      else if typeof inflow?.get is 'function'
        delete @_eqOutlets[inflow.cid]
        @_resetMultiget() if @_multiGet is inflow
    super

  toJSON: -> @_value

  # include array methods. note that all of these are preserved in closure compiler
  for method in ['length', 'join', 'push', 'pop', 'concat', 'reverse', 'shift', 'unshift', 'slice', 'splice', 'sort']
    @prototype[method] = do (method) -> ->
      Array.prototype[method].apply(@_value, arguments)

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
