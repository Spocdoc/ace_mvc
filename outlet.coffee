Cascade = require './cascade'

class Outlet extends Cascade
  constructor: (value) ->
    super ->
      if @indirect?
        @value = @indirect.get() if @indirect.get
        @value = @indirect.function() if @indirect.function
    @set value if value?

  get: -> @value

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
