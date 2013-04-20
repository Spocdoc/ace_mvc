Cascade = require './cascade'

class Outlet extends Cascade
  @stack = []

  constructor: (value) ->
    super ->
      if @indirect?
        Outlet.stack.push Outlet.stackLast if Outlet.stackLast
        Outlet.stackLast = this

        value = @indirect.get() if @indirect.get
        value = @indirect.function() if @indirect.function

        Outlet.stackLast = Outlet.stack.pop()

        if value == @value
          @stopPropagation()
        else
          @value = value

    @set value if value?

  get: ->
    @outflows.add Outlet.stackLast if Outlet.stackLast
    @value

  set: (value) ->
    if @value != value

      indirect = undefined
      sync = undefined

      if value and typeof value.get is 'function'
        indirect = { value: value, get: -> value.get.call(value) }

        if typeof value.set is 'function'
          sync = => value.set.call(value, @value)
          @outflows.add sync

      else if typeof value is 'function'
        indirect = { value: value, function: value }

      if indirect
        @detach()
        @sync = sync if sync
        @indirect = indirect
        value.outflows?.add?(this)
        @run()
      else
        @value = value
        @cascade()

    return @value

  detach: ->
    delete @indirect
    @outflows.remove @sync if @sync?
    super

module.exports = Outlet
