Url = require '../utils/url'
Route = require '../utils/route'
Outlet = require '../utils/outlet'
navigator = require '../utils/navigator'
debug = global.debug 'ace:router'

class Var
  constructor: (@outlet) ->

module.exports = class Router
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

    @vars = new Var

    context = Object.create globals

    for route in routes
      @[@length++] = route
      for varName of route.pathVarNames
        context[varName] = outlet = @uriOutlets[varName] ||= new Outlet undefined, context, true
        outlet.affectsPath = true
      for varName of route.otherVarNames
        context[varName] = @uriOutlets[varName] ||= new Outlet undefined, context, true

    varOutlets = {}
    context['var'] = (path, value) =>
      unless outlet = varOutlets[path]
        v = @vars
        v = (v[p] ||= new Var) for p in path.split '/' when p
        outlet = v.outlet = varOutlets[path] = new Outlet value, context, true
      outlet

    if useNavigator
      @route url = (@navigator = navigator(@route, this)).url

      @routeSearch = new Outlet
      @routeSearch.value = @current
      @routeSearch.func = (=>
        for r in this when r.matchOutlets @uriOutlets
          return @current = r)

      @uriFormatter = new Outlet
      @uriFormatter.value = url.href
      @uriFormatter.func = (=> @current?.format @uriOutlets)

      @routeSearch.addOutflow @uriFormatter
      @uriFormatter.addOutflow new Outlet => @navigator(@uriFormatter.value)

      for varName, outlet of @uriOutlets
        outlet.addOutflow @routeSearch if outlet.affectsPath
        outlet.addOutflow @uriFormatter

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
