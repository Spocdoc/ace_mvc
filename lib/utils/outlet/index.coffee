{argNames} = require '../u'
makeIndex = require '../id'
debugError = global.debug 'ace:error'

class Outlet
  (@roots = []).depth = 0

  constructor: (value, @context, auto) ->
    @auto = if auto then this else null
    @index = makeIndex()

    # these are all sparse arrays
    @equivalents = []
    @changing = []
    @outflows = []

    @set value

  @openBlock: ->
    ++Outlet.roots.depth
    return

  @closeBlock: ->
    unless --Outlet.roots.depth
      outlet._runSource() for outlet in Outlet.roots.splice(0)
    return

  toString: -> @index

  set: (value, version) ->
    if typeof value is 'function'
      @_setFunc value, version
    else if value instanceof Outlet
      @_setOutlet value
    else
      @_setValue value, version
    return

  _setValue: (value, version=@version) ->
    return if @pending or (@value is value and @version is version)
    @value = value; @version = version
    Outlet.openBlock()
    equiv._setValue value, version for index, equiv of @equivalents
    for index, outflow of @outflows when !outflow.pending
      outflow._setPendingTrue()
      Outlet.roots.push outflow
    Outlet.closeBlock()
    return

  _setOutlet: (outlet) ->
    return if @equivalents[outlet]
    if outlet.pending
      @_setPendingTrue()
    else
      @_setValue outlet.value, outlet.version
    @equivalents[outlet] = outlet
    outlet.equivalents[this] = this
    return

  _setFunc: (@func, context) ->
    context && @context = context
    @funcArgOutlets = []
    (@funcArgOutlets[i] = @context[name]).addOutflow this for name,i in argNames func
    @_setPendingTrue()
    if Outlet.roots.depth
      Outlet.roots.push this
    else
      @_runSource()
    return

  modified: -> @set @value, makeIndex()

  get: ->
    if out = Outlet.auto
      a = out._autoInflows ||= {}
      if a[this]?
        a[this] = 1
      else unless @outflows[out]
        a[this] = (out.autoInflows ||= {})[this] = this
        @outflows[out] = out
        throw 'pending' if @pending

    if @value and len = arguments.length
      if @value.get?.length > 0
        return @value.get(arguments...)
      else if len is 1 and typeof @value is 'object'
        return @value[arguments[0]]
    
    @value

  addOutflow: (outflow) ->
    outflow = new Outlet outflow if typeof outflow is 'function'
    unless @outflows[outflow]
      @outflows[outflow] = outflow
      outflow._setPendingTrue this if @pending
    outflow

  removeOutflow: (outflow) ->
    if @outflows[outflow]
      delete @outflows[outflow]
      outflow._setPendingFalse this if @pending
    return


  unset: (outlet) ->
    return unless @equivalents[outlet]
    delete @equivalents[outlet]
    delete outlet.equivalents[this]
    if @pending
      unless outlet._shouldPend()
        outlet._setPendingFalse()
      else unless @_shouldPend()
        @_setPendingFalse()
    return

  equivalenceSet: (set) ->
    unless set[this]
      set[this] = 1
      outlet.equivalenceSet set for index, outlet of @equivalents
    return
  
  _shouldPend: ->
    @equivalenceSet set = []
    for index, outlet of set when outlet.changing.length or outlet in Outlet.roots
      return true
    false

  _setPendingTrue: (source) ->
    @changing[source] = 1 if source
    unless @pending
      @pending = true
      equiv._setPendingTrue() for index, equiv of @equivalents
      outflow._setPendingTrue(this) for index, outflow of @outflows
    return

  _setPendingFalse: (source) ->
    if source
      delete @changing[source]
      return if @changing.length
    if @pending
      @pending = false
      equiv._setPendingFalse() for index, equiv of @equivalents
      outflow._setPendingFalse(this) for index, outflow of @outflows
    return

  _runSource: (source) ->
    delete @changing[source] if source
    return unless @pending and !@changing.length
    Outlet.openBlock()
    prev = Outlet.auto; Outlet.auto = @auto
    try
      @_autoInflows[index] = 0 for index of @_autoInflows
      value = @_runFunc()
      for index,used of @_autoInflows when !used
        delete @_autoInflows[index]
        delete @autoInflows[index].outflows[this]
        delete @autoInflows[index]
    catch _error
      return if _error is 'pending'
      debugError _error.stack if _error
    finally
      Outlet.auto = prev
      Outlet.closeBlock()
    if outlet = @funcOutlet
      return @_setPendingFalse() if value is outlet
      delete @equivalents[outlet]
      delete outlet.equivalents[this]
      delete @funcOutlet
    if value instanceof Outlet
      @equivalents[value] = value
      value.equivalents[this] = this
      @funcOutlet = value
      return if value.pending
      value = value.value
    @_setFuncValue value
    outlet?._setPendingFalse()
    return

  _runFunc: ->
    @funcArgs ||= []
    @funcArgs[i] = outlet.value for outlet, i in @funcArgOutlets
    @func.apply @context, @funcArgs

  _setFuncValue: (value) ->
    if @value is value
      @_setPendingFalse()
    else
      @pending = false
      @value = value
      equiv._setFuncValue value for index, equiv of @equivalents
      outflow._runSource this for index, outflow of @outflows
    return

module.exports = Outlet
