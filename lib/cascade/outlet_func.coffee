module.exports = (Outlet) ->
  Outlet.stack = []
  Outlet.func = {}

  Outlet.prototype.get = ->
    @outflows.add Outlet.stackLast if Outlet.stackLast
    if arguments.length and @_indirect?.get
      obj = @_indirect.value
      obj.get.apply(obj,arguments)
    else
      @_value

  Outlet.prototype._funcDone = (value) ->
    if value == @_value
      @stopPropagation()
    else
      @_value = value

  Outlet.func.sync = ->
    if @_indirect?
      Outlet.stack.push Outlet.stackLast if Outlet.stackLast
      Outlet.stackLast = this

      value = @_indirect.get() if @_indirect.get
      value = @_indirect.function() if @_indirect.function

      Outlet.stackLast = Outlet.stack.pop()
      @_funcDone(value)

  Outlet.func.async = (done) ->
    # track the synchronous part's outlet calls
    Outlet.stack.push Outlet.stackLast if Outlet.stackLast
    Outlet.stackLast = this

    num = @_calculateNum
    @_indirect.function (value) =>
      @_funcDone(value) if num == @_calculateNum
      done()

    Outlet.stackLast = Outlet.stack.pop()


