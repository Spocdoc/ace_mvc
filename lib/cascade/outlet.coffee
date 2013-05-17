Cascade = require './cascade'

# options:
#     silent    don't run the function immediately
#     value     initialize the value (eg, if the value parameter is a function; used with silent)
class Outlet extends Cascade
  constructor: (value, options={}) ->
    super Outlet.func.sync
    @set value, options

  get: -> # redefined in outlet_func

  unset: (value) ->
    @_removeIndirect() if @_indirect?.value == value

  inc: (delta) -> @set(@_value + delta)
  push: (item) ->
    @_value.push(item)
    @set(@_value)

  # when the value is an object, call to indicate the contents of the object
  # have changed
  changed: -> @set(@_value)

  set: (value, options={}) ->
    if @_value != value or (value and value.constructor in [Array,Object])

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
        @func = if indirect.function?.length then Outlet.func.async else Outlet.func.sync
        @run() unless options.silent
      else
        @_value = value
        @_calculateNum = (@_calculateNum || 0) + 1 # pretend the function was re-run
        @cascade() unless options.silent

    return @_value

  _removeIndirect: ->
    @func = Outlet.func.sync
    @_indirect.value.outflows?.remove this
    delete @_indirect
    @outflows.remove @_sync if @_sync?

  detach: ->
    @_removeIndirect() if @_indirect
    super

  toJSON: -> @_value

module.exports = Outlet
require('./outlet_func')(Outlet)

