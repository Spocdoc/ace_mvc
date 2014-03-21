Outlet = require 'outlet'
Var = require './var'

module.exports = class Context
  constructor: (@router, config, globals) ->
    @[k] = v for k,v of globals
    @[k] = v for k,v of config['methods']

    @globals = @['globals'] = globals
    @configure = config['configure']
    @start = config['start']
    @afterPush = config['afterPush']
    @_varCache = {}

  'outlet': (value) -> new Outlet value, this, true

  'var': (path, value) ->
    return outlet if outlet = @_varCache[path]
    outlet = if value?.uriOutlet then value else new Outlet value, this, true
    v = @router.vars
    v = (v[p] ||= new Var) for p in path.split '/' when p
    v.outlet = @_varCache[path] = outlet

  'map': (obj) ->
    for k, v of obj
      if typeof @[k] is 'function'
        if Array.isArray v
          @[k].apply this, v
        else
          @[k].call this, v
      else # assume an outlet
        if typeof v is 'string'
          if v.charAt(0) is '/'
            @['var'] v, @[k]
          else if typeof @[v] is 'function'
            @[k][v]()
        else # assume object
          @[k]['map'] v
    return

