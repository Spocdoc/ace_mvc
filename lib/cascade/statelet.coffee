Cascade = require './cascade'
Outlet = require './outlet'
debug = global.debug 'ace:cascade:statelet'

class StateletRunner extends Cascade
  constructor: (@getset, options) ->

    @enableGet = new Outlet options.enableGet ? true
    @enableSet = new Outlet options.enableSet ? true

    # empty function. the statelet will call the runner's get()
    super ->

    @enableSet.outflows.add =>
      unless @_willSet
        @_willSet = true
        @_postblock()
      return

    @_postblock = new Cascade.Postblock =>
      debug "running postblock: #{@}"
      @_willSet = false
      @getset?(@_value) if @enableSet.get()
      return

  get: ->
    @_value = if @getset and @enableGet.get() then @getset() else @_value

  set: (value) ->
    debug "set #{@constructor.name} [#{@cid}] to [#{value}]"
    return @_value if @_value is value or  value instanceof Cascade
    @_value = value
    unless @_willSet
      @_willSet = true
      @_postblock()

  toString: -> "#{@constructor.name} [#{@cid}] value [#{@_value}] g/s: [#{@enableGet.get()}/#{@enableSet.get()}]"

class Statelet extends Outlet
  constructor: (getset, options={}) ->
    @runner = new StateletRunner getset, options
    super @runner, options

    @enableGet = @runner.enableGet
    @enableSet = @runner.enableSet

    @enableGet.outflows.add => @update()

    @outflows.add => @runner.set @_value

  update: ->
    @run @runner

  toJSON: -> undefined

module.exports = Statelet
