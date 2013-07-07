Url = require '../utils/url'
Route = require '../utils/route'
navigator = require '../utils/navigator'
debugCascade = global.debug 'ace:cascade'
debug = global.debug 'ace:routing'

module.exports = (pkg) ->

  class Var
    constructor: (@outlet) ->

  {Outlet, Cascade} = (pkg.cascade || require('../cascade')(pkg))
  mvc = pkg.mvc || require('../mvc')(pkg)

  pkg.Router = class Router
    constructor: (routes, vars, useNavigator) ->
      @outlets = {}
      @length = 0

      @routeSearch = new Outlet
      @uriFormatter = new Outlet
      @routeSearch.outflows.add @uriFormatter

      @vars = new Var

      context = new mvc.Global

      for route in routes
        @push route
        for varName of route.pathVarNames when !@outlets[varName]
          context[varName] = outlet = @outlets[varName] = new Outlet
          outlet.outflows.add @routeSearch
          outlet.outflows.add @uriFormatter
        for varName of route.otherVarNames when !@outlets[varName]
          context[varName] = outlet = @outlets[varName] = new Outlet
          outlet.outflows.add @uriFormatter

      varOutlets = {}
      context['var'] = (path, value) =>
        unless outlet = varOutlets[path]
          debug "Added new variable at #{path}"
          v = @vars
          v = (v[p] ||= new Var) for p in path.split '/' when p
          outlet = v.outlet = varOutlets[path] = new Outlet value, auto: true, outlets: @outlets
        outlet

      if useNavigator
        @route url = (@navigator = navigator(@route, this)).url

        @routeSearch.set @current, silent: true
        @routeSearch.set (=>
          for r in this when r.matchOutlets @outlets
            return @current = r
          debug "routeSearch: no route found using outlets"), silent: true

        @uriFormatter.set url.href, silent: true
        @uriFormatter.set (=> @current?.format @outlets), silent: true
        @uriFormatter.outflows.add => @navigator(@uriFormatter.value)

      vars.call context

    push: (route) ->
      @[@length++] = route
      @length

    route: (url) ->
      debug "Routing #{url}"
      url = new Url(url, slashes: false) unless url instanceof Url

      Cascade.Block =>
        for route in this when route.match url, @outlets
          return @current = route

      debug "no match for #{url}"

module.exports.getRoutes = (config) ->
  debug "getRoutes"
  routes = []
  config['routes'] (args...) -> routes.push new Route args...
  routes

module.exports.getVars = (config) ->
  config['vars']
