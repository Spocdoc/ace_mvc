Url = require '../utils/url'
Route = require './route'
Outlet = require '../utils/outlet'
Context = require './context'
navigate = require '../utils/navigate'
debug = global.debug 'ace:router'

class Var
  constructor: (@outlet) ->

module.exports = class Router
  @buildRoutes = (config) ->
    return config unless typeof config['list'] is 'function'

    routes = []
    moreArgs = []
    config._vars = [ otherVars = {}, pathVars = {} ]

    config['list'] (args...) ->
      route = new Route moreArgs.concat(args...)...

      varNames = otherVars[route.name || ''] ||= []
      varNames.push q.varNames... if q = route.query
      varNames.push q.varNames... if q = route.hash

      if route.path
        (pathVars[route.name || ''] ||= []).push route.path.varNames...
        routes.push route
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
    @routes = if Array.isArray(config['list']) then config['list'] else Router.buildRoutes config
    @uriOutlets = {}
    @length = 0
    @vars = new Var

    context = new Context this, config, globals

    for a,i in config._vars when a['']
      @_addUriOutlets a[''], @uriOutlets, context, i

    for vars,i in config._vars
      for name,varNames of vars when name
        @_addUriOutlets varNames, @uriOutlets[name] = Object.create(@uriOutlets), context[name] = Object.create(context), i

    context.configure()
    context.start()
    return

  useNavigate: Outlet.block ->
    @navigate = navigate.listen @route, this
    @route url = @navigate.url

    @routeSearch = new Outlet ->
    @routeSearch.value = @routeSearch['value'] = @current
    @routeSearch.func = =>
      for r in @routes when r.matchOutlets @uriOutlets
        return @current = r

    @uriFormatter = new Outlet ->
    @uriFormatter.value = @uriFormatter['value'] = url
    @uriFormatter.func = =>
      new Url @current?.format @uriOutlets

    lastRoute = undefined
    lastPathname = undefined

    @routeSearch.addOutflow @uriFormatter
    @uriFormatter.addOutflow new Outlet =>
      if @current is lastRoute and @current.path.shouldReplace(lastPathname, @uriFormatter.value.pathname)
        @navigate.replace @uriFormatter.value
      else
        lastRoute = @current
        @navigate(@uriFormatter.value)
      lastPathname = @uriFormatter.value.pathname
      return

    for varName, outlet of @uriOutlets
      outlet.addOutflow @routeSearch if outlet.affectsRouteChoice
      outlet.addOutflow @uriFormatter

    return

  matchOutlets: ->
    if @navigate
      @navigate.url.href
    else
      for r in @routes when r.matchOutlets @uriOutlets
        return r.format @uriOutlets
      ''

  route: Outlet.block (url) ->
    debug "Routing #{url}"
    url = new Url(url, slashes: false) unless url instanceof Url
    for route in @routes when route.match url, @uriOutlets
      return @current = route
    debug "no match for #{url}"
    return
