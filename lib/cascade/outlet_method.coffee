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

  # outlets is optional
  # func [, outlets [, options]]
  constructor: (func, outlets, options={}) ->
    # prevent super constructor from calling `run` immediately
    @run = ->
    super (=>
      changed = false
      args = []
      @_values ||= []

      `var i, len, arg;
      for (i = 0, len = _this._argOutlets.length; i < len; i = i + 1) {
        arg = _this._argOutlets[i].get();
        changed || (changed = (arg != _this._values[i]));
        args.push(arg);
      }`

      if changed
        @_values = args
        return func.apply(options.context, @_values) if not @_silent
      return @_value
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
    @_argOutlets.push outlets[name] for name in @_names
    @_silent = options.silent
    @run()
    delete @_silent
    return

  detach: ->
    # retain the func, but remove arg outlets
    @_argOutlets = []
    indirect = @_indirect
    ret = super
    @_indirect = indirect
    return ret

  toJSON: -> undefined

module.exports = OutletMethod
