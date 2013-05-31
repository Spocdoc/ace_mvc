Cascade = require './cascade'
Outlet = require './outlet'
debug = global.debug 'ace:cascade'

class OutletMethod extends Outlet
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
    @_omFunc = =>
      args = []
      args.push a.get() for a in @_argOutlets
      func.apply(options.context, args)

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
    ret

  toJSON: -> undefined

module.exports = OutletMethod
