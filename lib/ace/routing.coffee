Router = require '../routes/router'
Route = require '../routes/route'
PathBuilder = require '../routes/path_builder'
Navigator = require '../navigator'
Cascade = require '../cascade/cascade'
Outlet = require '../cascade/outlet'

class Routing
  constructor: (@ace, @navigate, Variable) ->
    @uriOutlets = {}
    @variables = []
    @variableFactory = (path, fn) =>
      @variables.push variable = new Variable path, fn
      variable

  @buildRoutes: (config, routes = []) ->
    config.routes (uri, qs, outletHash) =>
      [outletHash,qs] = [qs, undefined] if not outletHash and typeof qs isnt 'string'
      routes.push new Route(uri, qs, outletHash)
    routes

  enable: (config,routes) ->
    @router ||= new Router @uriOutlets
    routes = @constructor.buildRoutes(config) unless routes

    for route in routes
      @router.push route
      for spec in route.specs
        @uriOutlets[spec.key] ?= new Outlet

    config.vars @uriOutlets, @variableFactory, @ace

  push: ->
    return unless @navigator
    @navigator.push()

  # args are passed to navigator
  # @throws unless enable(routes) has been called
  enableNavigator: (args...) ->
    return if @navigator
    throw new Error("Must enable routes first") unless @router

    @navigator = new Navigator args...
    @navigator.on 'navigate', @_navigate, @

    @pathBuilder = new PathBuilder @router
    @pathBuilder.outflows.add =>
      @navigator.replace @pathBuilder.get()

    return

  _navigate: (arg) ->
    if typeof arg is 'number'
      @navigate arg
    else
      Cascade.Block =>
        @navigate()
        @router.route arg
    return


module.exports = Routing

