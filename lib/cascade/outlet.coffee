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

  enterContext: -> Outlet.enterContext this
  exitContext: -> Outlet.exitContext()
  context: (fn) -> Outlet.context(fn, this)

  constructor: (value, options={}) ->
    @_multiGet = undefined
    @_eqFuncs = {}
    @_eqInflows = {}

    super (done) =>
      (break if found = @_eqInflows[change.cid] || @_eqFuncs[change.cid]) for change in @changes

      @enterContext()
      try

        if typeof found is 'function'
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
            done()

        else if found
          @stopPropagation() if @_value is (value = found.get())
          @_value = value
          done()

        else
          values = []
          num = @_calculateNum
          next = =>
            if num is @_calculateNum and values.length
              @stopPropagation() if @_value is (value = values[values.length-1])
              @_value = value
            done()

          count = 0

          for cid,fn of @_eqFuncs
            ++count
            if fn.length > 0
              fn (value) =>
                values.push value
                next() unless --count
            else
              values.push fn()
              next() unless --count

      finally
        @exitContext()

      return

    @set value, options

  get: ->
    @outflows.add Outlet.stackLast if Outlet.stackLast

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
        @_eqFuncs[value.cid] = value

      else if typeof value?.get is 'function'
        value.cid ||= Cascade.id()
        @_multiGet = value if value.get.length > 0
        @_eqInflows[value.cid] = value
        @outflows.add value
        value.set this if typeof value.set is 'function'

      else
        @_value = value
        @_calculateNum = (@_calculateNum || 0) + 1 # pretend the function was just re-run to get this value
        @cascade() unless options.silent
        return @_value

      @run(value) unless options.silent

    return @_value

  unset: (value) ->
    if typeof value is 'function'
      delete @_eqFuncs[value.cid]

    else if typeof value?.get is 'function'
      return unless @_eqInflows[value.cid]
      delete @_eqInflows[value.cid]
      @_resetMultiget() if @_multiGet is value
      @outflows.remove value
      value.unset this

    else unless value?
      @_multiGet = undefined
      @_eqFuncs = {}
      @unset value for cid,value of @_eqInflows

    return

  toJSON: -> @_value

  detach: (inflow) ->
    unless inflow?
      @_eqFuncs = {}
      @_eqInflows = {}
      @_multiGet = undefined
    else if inflow.cid
      if typeof inflow is 'function'
        delete @_eqFuncs[inflow.cid]
      else if typeof inflow?.get is 'function'
        delete @_eqInflows[inflow.cid]
        @_resetMultiget() if @_multiGet is inflow
    super

  # include array methods. note that all of these are preserved in closure compiler
  for method in ['length', 'join', 'push', 'pop', 'concat', 'reverse', 'shift', 'unshift', 'slice', 'splice', 'sort']
    @prototype[method] = ->
      Array.prototype[method].apply(@_value, arguments)

  inc: (delta) -> @set(@_value + delta)

  _resetMultiget: ->
    @_multiGet = undefined
    break for cid,o of @_eqInflows when o.get.length > 0 and @_multiGet = o
    return

module.exports = Outlet
