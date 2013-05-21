Cascade = require './cascade'
Outlet = require './outlet'


class Statelet extends Outlet
  constructor: (@getset, options={}) ->
    @enableGet = new Outlet options.enableGet ? true
    @enableSet = new Outlet options.enableSet ? true

    @_postblock = new Cascade.Postblock =>
      delete @_willSet
      @getset(@_value) if @enableSet.get()
      return

    @enableSet.outflows.add =>
      unless @_willSet
        @_willSet = true
        @_postblock()
      return

    @_sFunc = =>
      value = if @enableGet.get() then @getset() else @_value
      @stopPropagation() if value == @_value
      @_value = value

    super @_sFunc, options

    @enableGet.outflows.add this

  set: (value, options) ->
    ret = super
    unless typeof value is 'function' or typeof value?.get is 'function'
      unless @_willSet
        @_willSet = true
        @_postblock()
    ret

  detach: ->
    ret = super
    @enableGet.outflows.add this
    @set @_sFunc, silent: true
    ret

module.exports = Statelet
