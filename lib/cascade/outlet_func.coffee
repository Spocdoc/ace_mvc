module.exports = (Outlet) ->
  Outlet.stack = []
  Outlet.func = {}


  # ordinarily, outlets automatically add outflows to any outlet that's
  # retrieved in the current outlet's function. when this is unwanted,
  # execute the function in a new Outlet.context
  Outlet.context = (fn) ->
    @stack.push @stackLast
    @stackLast = null
    ret = fn()
    @stackLast = @stack.pop()
    ret

  Outlet.enterContext = ->
    @stack.push @stackLast
    @stackLast = null
    return

  Outlet.exitContext = ->
    @stackLast = @stack.pop()
    return

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


