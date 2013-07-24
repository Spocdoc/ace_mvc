Url = require '../utils/url'
Route = require '../utils/route'
Outlet = require '../utils/outlet'
navigator = require '../utils/navigator'
debug = global.debug 'ace:router'

class Var
  constructor: (@outlet) ->

class Router
  @getRoutes = (config) ->
    routes = []
    config['routes'] (args...) -> routes.push new Route args...
    routes

  @getVars = (config) ->
    config['vars']

  constructor: (routes, vars, globals, useNavigator) ->
    Outlet.openBlock()

    @uriOutlets = {}
    @length = 0

    (@routeSearch = new Outlet).addOutflow @uriFormatter = new Outlet

    @vars = new Var

    context = Object.create globals.app

    for route in routes
      @[@length++] = route
      for varName of route.pathVarNames
        context[varName] = outlet = @uriOutlets[varName] ||= new Outlet undefined, context, true
        outlet.addOutflow @routeSearch
        outlet.addOutflow @uriFormatter
      for varName of route.otherVarNames
        context[varName] = outlet = @uriOutlets[varName] ||= new Outlet undefined, context, true
        outlet.addOutflow @uriFormatter

    varOutlets = {}
    context['var'] = (path, value) =>
      unless outlet = varOutlets[path]
        v = @vars
        v = (v[p] ||= new Var) for p in path.split '/' when p
        outlet = v.outlet = varOutlets[path] = new Outlet value, context, true
      outlet

    if useNavigator
      @route url = (@navigator = navigator(@route, this)).url

      @routeSearch.value = @current
      @routeSearch.func = (=>
        for r in this when r.matchOutlets @uriOutlets
          return @current = r)

      @uriFormatter.value url.href
      @uriFormatter.func = (=> @current?.format @uriOutlets)
      @uriFormatter.addOutflow new Outlet => @navigator(@uriFormatter.value)

    vars.call context
    Outlet.closeBlock()
    return

  route: (url) ->
    debug "Routing #{url}"
    url = new Url(url, slashes: false) unless url instanceof Url
    Outlet.openBlock()
    try
      for route in this when route.match url, @uriOutlets
        return @current = route
    finally
      Outlet.closeBlock()
    debug "no match for #{url}"

module.exports = Router
