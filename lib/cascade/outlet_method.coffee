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
  # outlets is optional
  constructor: (context, func, outlets) ->
    return new OutletMethod(context, func, outlets) if not (this instanceof Outlet)

    if outlets is undefined
      outlets = func
      func = context
      context = null

    # prevent super constructor from calling `run` immediately
    @run = ->
    super =>
      changed = false
      args = []
      @values ||= []

      `
      var i, len, arg;
      for (i = 0, len = _this.argOutlets.length; i < len; i = i + 1) {
        arg = _this.argOutlets[i].get();
        changed || (changed = (arg != _this.values[i]));
        args.push(arg);
      }
      `

      if changed
        @values = args
        return func.apply(context, @values)
      else
        return @value

    delete @run
    @names = getArgNames(func)
    @rebind outlets if outlets

    # disallow assigning the value or changing the func
    # @set = ->

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

  serializedValue: ->
    JSON.stringify { @value, @values }

  restoreValue: (data) ->
    { @value, @values } = JSON.parse data
    return @value

module.exports = OutletMethod
