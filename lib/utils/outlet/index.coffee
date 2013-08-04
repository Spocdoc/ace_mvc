{argNames} = require '../u'
makeIndex = require '../id'
debugError = global.debug 'ace:error'

module.exports = class Outlet
  (@roots = []).depth = 0
  @debug = {}

  constructor: (value, @context, auto) ->
    @auto = if auto then this else null
    @index = makeIndex()

    Outlet.debug[this] = this

    @equivalents = {}
    (@changing = {}).length = 0
    @outflows = {}

    @set value

  @openBlock: ->
    ++Outlet.roots.depth
    return

  @closeBlock: ->
    unless --(roots = Outlet.roots).depth
      ++roots.depth
      `for (var i = 0, len = 0; (i < len) || (i < (len = roots.length)); ++i) roots[i]._runSource();`
      --roots.depth
      roots.length = 0
    return

  toString: -> @index
  'toOJSON': ->
    if @value? then @value else null

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
    for index, outflow of @outflows when !outflow.root
      outflow.root = true
      Outlet.roots.push outflow
      outflow._setPendingTrue()
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
    @auto = null if i # TODO this is a workaround in lieu of a yet unimplemented better alternative
    @_setPendingTrue()
    if Outlet.roots.depth
      @root = true
      Outlet.roots.push this
    else
      @_runSource()
    return

  modified: -> @set @value, makeIndex()

  get: ->
    if (out = Outlet.auto) and this != out
      a = out._autoInflows ||= {}
      if a[this]?
        a[this] = 1
      else unless @outflows[out]
        a[this] = (out.autoInflows ||= {})[this] = this
        @outflows[out] = out
        if @pending
          out.changing[this] = ++out.changing.length
          throw 'pending'

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
    unless outlet
      for index, outlet of @equivalents
        delete @equivalents[index]
        delete outlet.equivalents[this]
        outlet._setPendingFalse() unless outlet._shouldPend {}

      @_setPendingFalse() unless @_shouldPend {}
    else
      return unless @equivalents[outlet]
      delete @equivalents[outlet]
      delete outlet.equivalents[this]
      if @pending
        unless outlet._shouldPend({})
          outlet._setPendingFalse()
        else unless @_shouldPend({})
          @_setPendingFalse()
    return

  _shouldPend: (visited) ->
    return true if @changing.length or @root
    visited[this] = 1
    for index, outlet of @equivalents when !visited[index] and outlet._shouldPend(visited)
      return true
    false

  _setPendingTrue: (source) ->
    @changing[source] = ++@changing.length if source and !@changing[source]
    unless @pending
      @pending = true
      except = @funcOutlet if @changing.length or @root
      equiv._setPendingTrue() for index, equiv of @equivalents when equiv isnt except
      outflow._setPendingTrue(this) for index, outflow of @outflows
    return

  _setPendingFalse: (source) ->
    if source and @changing[source]
        delete @changing[source]
        --@changing.length
    return if !@pending or @root or @changing.length
    if source and outlet = @funcOutlet
      unless outlet.pending
        @_setFuncValue outlet.value, outlet.version
    else
      @pending = false
      equiv._setPendingFalse() for index, equiv of @equivalents
      outflow._setPendingFalse(this) for index, outflow of @outflows
    return

  _runSource: (source) ->
    if source
      delete @changing[source]
      --@changing.length
      return if @root
    else if @changing.length
      Outlet.roots.push this
      return

    @root = false
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
      return outlet.pending or @_setFuncValue outlet.value, outlet.version if value is outlet
      delete @equivalents[outlet]
      delete outlet.equivalents[this]
      delete @funcOutlet
    if value instanceof Outlet
      @equivalents[value] = value
      value.equivalents[this] = this
      @funcOutlet = value
      return if value.pending
      version = value.version
      value = value.value
    @_setFuncValue value, version
    return

  _runFunc: ->
    @funcArgs ||= []
    if @funcArgOutlets
      @funcArgs[i] = outlet.value for outlet, i in @funcArgOutlets
    @func.apply @context, @funcArgs

  _setFuncValue: (value, version) ->
    return if @root or @changing.length
    if @value is value and @version is version
      @_setPendingFalse()
    else
      @pending = false
      @value = value
      equiv._setFuncValue value for index, equiv of @equivalents
      outflow._runSource this for index, outflow of @outflows
    return
