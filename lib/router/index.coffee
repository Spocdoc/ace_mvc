Url = require '../utils/url'
Route = require '../utils/route'
Navigator = require '../utils/navigator'
debugCascade = global.debug 'ace:cascade'
debug = global.debug 'ace:routing'

module.exports = (pkg) ->

  Outlet = (pkg.cascade || require('../cascade')(pkg)).Outlet
  mvc = pkg.mvc || require('../mvc')(pkg)

  pkg.Router = class Router
    constructor: (routes, vars) ->
      @outlets = {}
      @length = 0

      @routePush = new Outlet undefined
      @routeReplace = new Outlet undefined
      @routePush.outflows.add @routeReplace

      context = new mvc.Global

      for route in routes
        @push route
        for varName of route.pathVarNames when !@outlets[varName]
          context[varName] = outlet = @outlets[varName] = new Outlet undefined
          outlet.outflows.add @routePush
        for varName of route.otherVarNames when !@outlets[varName]
          context[varName] = outlet = @outlets[varName] = new Outlet undefined
          outlet.outflows.add @routeReplace

      varOutlets = {}
      context['var'] = (path) =>
        unless outlet = varOutlets[path]
          debug "Added new variable at #{path}"
          Outlet.addDir path, outlet = varOutlets[path] = new Outlet undefined, auto: true, outlets: @outlets
        outlet

      vars.call context

    push: (route) ->
      @[@length++] = route
      @length

    route: (url) ->
      debug "Routing #{url}"
      url = new Url(url, slashes: false) unless url instanceof Url

      for route in this
        return if route.match url, @outlets

      debug "no match for #{url}"

    enableNavigator: ->
      return if @navigator

      @navigator = new Navigator
      @navigator.on 'navigate', => @route @navigator.url

      @routePush.set =>
        (break) for r in this when r.matchOutlets(@outlets) && route = r
        debug "routePush: no route found using outlets" unless route
        route

      @routePush.outflows.add =>
        if route = @routePush.value
          @navigator.push route.format @outlets
        return

      @routeReplace.set do =>
        oldRoute = undefined
        =>
          if oldRoute isnt (route = @routePush.value)
            oldRoute = route
            @routeReplace.value
          else
            route?.format @outlets

      @routeReplace.outflows.add =>
        if @routeReplace.value
          @navigator.replace @routeReplace.value
        return

module.exports.getRoutes = (config) ->
  debug "getRoutes"
  routes = []
  config['routes'] (args...) -> routes.push new Route args...
  routes

module.exports.getVars = (config) ->
  config['vars']
