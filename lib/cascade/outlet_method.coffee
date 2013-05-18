Outlet = require './outlet'
Autorun = require './autorun'

class OutletMethod extends Outlet
  getArgNames = do ->
    regexComments = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
    regexFunction = /^function\s*[^\(]*\(([^\)]*)\)\s*\{([^]*)\}$/m
    regexTrim = /^\s*|\s*$/mg
    regexTrimCommas = /\s*,\s*/mg

    return (fn) ->
      fnText = Function.toString.apply(fn).replace(regexComments, '')
      argsBody = fnText.match(regexFunction)
      if str = argsBody[1].replace(regexTrim,'').replace(regexTrimCommas,',')
        str.split ','
      else
        []

  # outlets is optional
  # func [, outlets [, options]]
  constructor: (func, outlets, options={}) ->
    # prevent super constructor from calling `run` immediately
    @run = ->
    super (=>
      args = []
      args.push a.get() for a in @_argOutlets
      func.apply(options.context, args)
      ), options

    delete @run
    @_names = getArgNames(func)
    @rebind outlets, options if outlets

    # disallow assigning the value or changing the func
    # @set = ->

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
    # retain the func, but remove arg outlets
    @_argOutlets = []
    indirect = @_indirect
    ret = super
    @_indirect = indirect
    return ret

  toJSON: -> undefined

module.exports = OutletMethod
