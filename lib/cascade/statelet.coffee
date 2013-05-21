Cascade = require './cascade'

class Statelet extends Cascade
  constructor: (@getset, options={}) ->
    @_sFunc = =>
      value = if @enableGet() then @getset() else @_value
      @stopPropagation() if value == @_value
      @_value = value

    super =>

    @_getsetOutflow = [ (=> @getter()), (=> @setter()) ]

    @enableGet(options.enableGet ? true)
    @enableSet(options.enableSet ? true)

    @_value = options.value if options.value?
    @getter() if @getset and !options.silent

    @_postblock = new Cascade.Postblock => @_doSet()

  get: -> @_value
  set: (value, options) ->
    if typeof value is 'function'
      @getset = value
    else
      @_value = value
      @setter(options)
      @_calculateNum = (@_calculateNum || 0) + 1 # pretend the function was re-run
      @cascade() unless options?.silent

  setter: (options) ->
    if @enableSet() and !@_willSet
      @_willSet = true
      @_postblock()
    return

  getter: ->
    @run() if @enableGet()
    @_value

  enableGet: (arg) -> @_enable(0, arg)
  enableSet: (arg) -> @_enable(1, arg)

  _doSet: ->
    delete @_willSet
    @getset(@_value)

  _ter: ['getter','setter']
  _enable: (getOrSet, arg) ->
    enable = @_enable[getOrSet]

    if arg?
      out = @_getsetOutflow[getOrSet]

      enable.outflows.remove out if enable?.outflows?
      arg.outflows.add out if arg.outflows?

      @_enable[getOrSet] = arg
      return

    else
      if enable.get?
        enable.get()
      else
        !!enable

Statelet.prototype['getter'] = Statelet.prototype.getter
Statelet.prototype['setter'] = Statelet.prototype.setter

module.exports = Statelet
