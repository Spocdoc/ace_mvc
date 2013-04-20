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
      argsBody[1].replace(regexTrim,'').replace(regexTrimCommas,',').split(',')

  # context is optional
  constructor: (context, func, outlets) ->
    return new OutletMethod(context, func, outlets) if not (this instanceof Outlet)

    if outlets is undefined
      outlets = func
      func = context
      context = null

    # prevent super from running immediately
    @run = ->
    super =>
      # simplifying the below causes CoffeeScript to execute an anonymous function...
      args = []
      args.push outlet.get() for outlet in @argOutlets
      func.apply(context, args)

    delete @run
    @names = getArgNames(func)
    @rebind outlets

  # disallow setting
  # @set: ->

  # outlets is a hash from argument name to outlet
  # eg, {a: outletX, b: outletY}
  rebind: (outlets) ->
    @detach()
    @argOutlets.push outlets[name] for name in @names
    @run()

  detach: ->
    # retain the func, but remove arg outlets
    @argOutlets = []
    indirect = @indirect
    ret = super
    @indirect = indirect
    return ret

module.exports = OutletMethod
