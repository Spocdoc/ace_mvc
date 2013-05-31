Cascade = require './cascade'
Auto = require './auto'
debug = global.debug 'ace:cascade'

class OutletMethod extends Auto
  @name = 'OutletMethod'

  getArgNames = do ->
    regexComments = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
    regexFunction = /^function\s*[^\(]*\(([^\)]*)\)\s*\{([\s\S]*)\}$/m
    regexTrim = /^\s*|\s*$/mg
    regexTrimCommas = /\s*,\s*/mg

    return (fn) ->
      fnText = Function.toString.apply(fn).replace(regexComments, '')
      argsBody = fnText.match(regexFunction)
      if str = argsBody[1].replace(regexTrim,'').replace(regexTrimCommas,',')
        str.split ','
      else
        []

  constructor: (func, outlets, options={}) ->
    @_omSet = undefined
    @_omFunc = =>
      num = @_runNumber

      args = []
      args.push a.get() for a in @_argOutlets
      result = func.apply(options.context, args)

      return if num != @_runNumber

      if result instanceof Cascade
        rv = result.get() # fetch the result first, so if it's pending, the calculation will abort before setting
        if result isnt @_omSet
          @pending = false # this hackery is because outlet's set alters the run state to invalidate running functions, which isn't wanted here
          @unset @_omSet if @_omSet
          @set @_omSet = result, silent: true
          @pending = @running = true
        @_runNumber = num
        rv
      else
        result

    # prevent super constructor from calling `run` immediately
    @run = ->
    super undefined, options
    delete @run

    debug "new outlet method created: #{@} method [#{func.toString()}]"

    @_names = options.names || getArgNames(func)
    @set options.value, options if options.value
    @rebind outlets, options if outlets

  # outlets is a hash from argument name to outlet
  # eg, {a: outletX, b: outletY}
  rebind: (outlets, options={}) ->
    @detach()
    for name in @_names
      outlets[name].outflows.add this
      @_argOutlets.push outlets[name]
    @run() unless options.silent
    return this

  detach: ->
    ret = super
    @_argOutlets = []
    @set @_omFunc, silent: true
    @set @_omSet if @_omSet
    ret

  toJSON: -> undefined

module.exports = OutletMethod
