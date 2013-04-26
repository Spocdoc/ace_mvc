Cascade = require './cascade'

# options:
#     silent    don't run the function immediately
#     value     initialize the value (eg, if the value parameter is a function; used with silent)
class Outlet extends Cascade
  @stack = []

  constructor: (value, options={}) ->
    super ->
      if @_indirect?
        Outlet.stack.push Outlet.stackLast if Outlet.stackLast
        Outlet.stackLast = this

        value = @_indirect.get() if @_indirect.get
        value = @_indirect.function() if @_indirect.function

        Outlet.stackLast = Outlet.stack.pop()

        if value == @_value
          @stopPropagation()
        else
          @_value = value

    @set value, options

  get: ->
    @outflows.add Outlet.stackLast if Outlet.stackLast
    @_value

  unset: (value) ->
    @_removeIndirect() if @_indirect?.value == value

  set: (value, options={}) ->
    if @_value != value

      indirect = undefined
      sync = undefined

      if value and typeof value.get is 'function'
        indirect = { value: value, get: -> value.get.call(value) }

        if typeof value.set is 'function'
          sync = => value.set.call(value, @_value)
          @outflows.add sync

      else if typeof value is 'function'
        indirect = { value: value, function: value }

      if indirect
        @detach()
        @_sync = sync if sync
        @_indirect = indirect
        value.outflows?.add?(this)
        @_value = options.value if options.value?
        @run() if not options.silent?
      else
        @_value = value
        @cascade() if not options.silent?

    return @_value

  _removeIndirect: ->
    delete @_indirect
    @outflows.remove @_sync if @_sync?

  detach: ->
    @_removeIndirect()
    super

  toJSON: -> @_value

module.exports = Outlet
