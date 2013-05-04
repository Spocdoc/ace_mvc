Router = require '../routes/router'
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

  makeURIOutlets: (keys) ->
    for key in keys
      @uriOutlets[key] ?= new Outlet

  enable: (routes) ->
    @router ||= new Router @uriOutlets
    keys = {}
    routes.routes (uri, qs, outlets) =>
      [outlets,qs] = [qs, undefined] if not outlets and typeof qs isnt 'string'
      route = @router.add uri, qs, outlets
      keys[spec.key] = 1 for spec in route.specs

    @makeURIOutlets Object.keys(keys)
    routes.vars @uriOutlets, @variableFactory, @ace

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

