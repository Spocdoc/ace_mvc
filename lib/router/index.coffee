Uri = require 'uri-fork'
Route = require './route'
Outlet = require 'outlet'
Context = require './context'
navigate = require 'navigate-fork'
debug = global.debug 'ace:router'
Var = require './var'

module.exports = class Router
  @buildRoutes = (config) ->
    return config unless typeof config['list'] is 'function'

    routes = []
    moreArgs = []
    config._vars = [ otherVars = {}, pathVars = {} ]

    config['list'] (args...) ->
      route = new Route moreArgs.concat(args...)...

      varNames = otherVars[route.name || ''] ||= []
      varNames.push value for key, value of route.query?.obj
      varNames.push value for key, value of route.hash?.obj

      if route.path
        (pathVars[route.name || ''] ||= []).push route.path.keys...
        routes.push route
        (pathVars[''] ||= []).push key for key of route.path.outletHash
      else
        moreArgs.push args...

    config['list'] = routes
    config

  _addUriOutlets: (varNames, outlets, context, affectsRouteChoice) ->
    for varName in varNames
      unless outlet = outlets[varName]
        context[varName] = outlet = outlets[varName] = new Outlet undefined, context, true
        outlet.uriOutlet = true
      outlet.affectsRouteChoice ||= affectsRouteChoice
    return

  constructor: Outlet.block (config, globals) ->
    globals['router'] = this
    @routes = if Array.isArray(config['list']) then config['list'] else Router.buildRoutes(config)['list']
    @uriOutlets = {}
    @length = 0
    @vars = new Var

    @context = context = new Context this, config, globals
    @afterPushArg = {}
    @doAfterPush = false

    @afterPush = =>
      doAfterPush = @doAfterPush
      afterPushArg = @afterPushArg
      @setAfterPush = @doAfterPush = false
      @afterPushArg = {}
      @context.afterPush afterPushArg if doAfterPush
      return

    for a,i in config._vars when a['']
      @_addUriOutlets a[''], @uriOutlets, context, i

    for vars,i in config._vars
      for name,varNames of vars when name
        @_addUriOutlets varNames, @uriOutlets[name] ||= Object.create(@uriOutlets), context[name] ||= Object.create(context), i

    context.configure()
    context.start()
    return

  _getOutlets: (name) -> if name then @uriOutlets[name] else @uriOutlets

  'setAfterPushArg': (name, value) ->
    return if !@context.afterPush

    @afterPushArg[name] = value

    unless @setAfterPush
      @setAfterPush = true
      Outlet.atEnd @afterPush
    return

  serverUri: ->
    uri = new Uri(if @current then @current.format @_getOutlets @current.name else '')
    uri.setHash ''

  useNavigate: Outlet.block (canonicalUri) ->
    @navigate = navigate.listen @route, this
    if canonicalUri
      uri = new Uri canonicalUri
      uri.setHash @navigate.uri.hash
      @navigate.replaceNow uri
    else
      uri = @navigate.uri
    @route uri

    @routeSearch = new Outlet ->
    @routeSearch.value = @routeSearch['value'] = @current
    @routeSearch.func = =>
      for r in @routes when r.matchOutlets @_getOutlets r.name
        return @current = r

    @uriFormatter = new Outlet ->
    @uriFormatter.value = @uriFormatter['value'] = uri.uri
    @uriFormatter.func = => @current?.format @_getOutlets @current.name

    lastRoute = @current
    lastPathname = uri.pathname

    @routeSearch.addOutflow @uriFormatter
    @uriFormatter.addOutflow updateNavigate = new Outlet
    updateNavigate.func = =>
      uri = new Uri @uriFormatter.value
      if @current is lastRoute and @current.path.shouldReplace(lastPathname, uri.pathname)
        @navigate.replace uri
      else
        if @navigate.wouldPush uri
          @doAfterPush = true
          unless @setAfterPush or !@context.afterPush
            @setAfterPush = true
            Outlet.atEnd @afterPush

          # set old path outlets to undefined, for consistency
          if lastRoute and lastRoute isnt current = @current
            newOutlets = @_getOutlets current.name
            oldOutlets = @_getOutlets lastRoute.name
            oldNames = lastRoute.pathNames
            newNames = current.pathNames
            for name of oldNames when !newNames[name] or newOutlets[name] isnt oldOutlets[name]
              oldOutlets[name].set undefined

        lastRoute = @current
        @navigate uri
      lastPathname = uri.pathname
      return

    addOutflows = (outlets) =>
      for varName, outlet of outlets when outlets.hasOwnProperty varName
        if outlet instanceof Outlet
          outlet.addOutflow @routeSearch if outlet.affectsRouteChoice
          outlet.addOutflow @uriFormatter
        else
          addOutflows outlet
      return

    addOutflows @uriOutlets

    return

  matchOutlets: ->
    if @navigate
      @navigate.uri.uri
    else
      for r in @routes when r.matchOutlets outlets = @_getOutlets r.name
        return (@current = r).format outlets
      ''

  route: Outlet.block (uri) ->
    debug "Routing #{uri}"
    uri = new Uri uri unless uri instanceof Uri
    for route in @routes when route.match uri, newOutlets = @_getOutlets route.name
      if current = @current
        oldOutlets = @_getOutlets current.name
        oldNames = current.pathNames
        newNames = route.pathNames
        for name of oldNames when !newNames[name] or newOutlets[name] isnt oldOutlets[name]
          oldOutlets[name].set undefined
      return @current = route
    debug "no match for #{uri}"
    return
