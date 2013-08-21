Url = require '../utils/url'
Route = require '../utils/route'
Outlet = require '../utils/outlet'
navigate = require '../utils/navigate'
debug = global.debug 'ace:router'

class Var
  constructor: (@outlet) ->

module.exports = class Router
  @getRoutes = (config) ->
    routes = []
    moreArgs = []
    config['routes'] (args...) ->
      if typeof args[0] is 'string' and args[0].charAt(0) isnt '/'
        moreArgs.push args...
      else
        routes.push new Route moreArgs.concat(args...)...
    routes

  @getVars = (config) ->
    config['vars']

  constructor: (routes, vars, globals, useNavigate) ->
    Outlet.openBlock()

    @uriOutlets = {}
    @length = 0

    @vars = new Var

    context = Object.create globals

    for route in routes
      @[@length++] = route
      for varName of route.pathVarNames
        context[varName] = outlet = @uriOutlets[varName] ||= new Outlet undefined, context, true
        outlet.uriOutlet = varName
        outlet.affectsRouteChoice = true
      for varName of route.otherVarNames
        outlet = context[varName] = @uriOutlets[varName] ||= new Outlet undefined, context, true
        outlet.uriOutlet = varName

    varOutlets = {}
    context['var'] = (path, value) =>
      return outlet if outlet = varOutlets[path]

      if varName = value?.uriOutlet
        outlet = @uriOutlets[varName]
      else
        outlet = new Outlet value, context, true

      v = @vars
      v = (v[p] ||= new Var) for p in path.split '/' when p
      v.outlet = varOutlets[path] = outlet

    context['outlet'] = (value) => new Outlet value, context, true

    @routeSearch = new Outlet ->
    @uriFormatter = new Outlet ->
    for varName, outlet of @uriOutlets
      outlet.addOutflow @routeSearch if outlet.affectsRouteChoice
      outlet.addOutflow @uriFormatter

    @navigate = navigate.listen @route, this if useNavigate

    vars.call context
    Outlet.closeBlock()
    return

  useNavigate: ->
    Outlet.openBlock()
    @route url = @navigate.url

    @routeSearch.value = @routeSearch['value'] = @current
    @routeSearch.func = (=>
      for r in this when r.matchOutlets @uriOutlets
        return @current = r)

    @uriFormatter.value = @uriFormatter['value'] = url.href
    @uriFormatter.func = (=> @current?.format @uriOutlets)

    @routeSearch.addOutflow @uriFormatter
    @uriFormatter.addOutflow new Outlet => @navigate(@uriFormatter.value)

    Outlet.closeBlock()
    return

  matchOutlets: ->
    if @navigate
      @navigate.url.href
    else
      for r in this when r.matchOutlets @uriOutlets
        return r.format @uriOutlets
      ''

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
