Cascade = require './cascade'

class Outlet extends Cascade
  @stack = []

  constructor: (value) ->
    super ->
      if @indirect?
        Outlet.stack.push Outlet.stackLast if Outlet.stackLast
        Outlet.stackLast = this
        @value = @indirect.get() if @indirect.get
        @value = @indirect.function() if @indirect.function
        Outlet.stackLast = Outlet.stack.pop()
    @set value if value?

  get: ->
    @outflows.add Outlet.stackLast if Outlet.stackLast
    @value

  set: (value) ->
    if @value != value
      @indirect?.value.outflows?.remove?(this)

      @value = value

      if @value
        if typeof @value.get is 'function'
          @indirect = { value: @value, get: -> value.get.call(value) }
        else if typeof @value is 'function'
          @indirect = { value: @value, function: @value }
        else delete @indirect

        @value.outflows?.add?(this)
      @run()
    return @value

  detach: ->
    delete @indirect
    super


module.exports = Outlet
