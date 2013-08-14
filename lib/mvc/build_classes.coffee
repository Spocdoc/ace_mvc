Outlet = require '../utils/outlet'

special = ['constructor','static','view','outlets','outletMethods','template','inWindow']

addOutlets = do ->
  addOutlet = (clazz, outlet) ->
    if typeof outlet isnt 'string'
      clazz.outletDefaults[k] = v for k,v of outlet
    else
      clazz.outletDefaults[outlet] = undefined
    return

  (config, clazz) ->
    clazz['outletDefaults'] = clazz.outletDefaults = {}

    if outlets = config['outlets']
      if Array.isArray outlets
        addOutlet clazz, k for k in outlets
      else
        addOutlet clazz, outlets

    if outletMethods = config['outletMethods']
      clazz.outletDefaults["_#{i}"] = m for m,i in outletMethods

    return

addStatic = (config, clazz) ->
  clazz[name] = fn for name, fn of config['static']
  return

addMethods = do ->
  addMethod = (clazz, name, method) ->
    clazz.prototype[name] = ->
      Outlet.openBlock()
      try
        method.apply this, arguments
      finally
        Outlet.closeBlock()
    return

  (config, clazz) ->
    for name, method of config when name.charAt(0) isnt '$' and not (name in special)
      if clazz.outletDefaults.hasOwnProperty name
        clazz.outletDefaults[name] = method
      else
        addMethod clazz, name, method
    return

module.exports = (configs, base) ->
  types = {}
  for type, config of configs
    types[type] = class Component extends base
      aceType: type
      aceConfig: config

      addStatic config, this
      addOutlets config, this
      addMethods config, this

  types
