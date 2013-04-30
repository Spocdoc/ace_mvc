Cascade = require './cascade'

# options:
#     silent    don't run the function immediately
#     value     initialize the value (eg, if the value parameter is a function; used with silent)
class Outlet extends Cascade
  constructor: (value, options={}) ->
    super Outlet.func.sync
    @set value, options

  get: -> @_value

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
        @func = if indirect.function?.length then Outlet.func.async else Outlet.func.sync
        @run() if not options.silent?
      else
        @_value = value
        @cascade() if not options.silent?

    return @_value

  _removeIndirect: ->
    @func = Outlet.func.sync
    delete @_indirect
    @outflows.remove @_sync if @_sync?

  detach: ->
    @_removeIndirect()
    super

  toJSON: -> @_value

module.exports = Outlet
require('./outlet_func')(Outlet)

