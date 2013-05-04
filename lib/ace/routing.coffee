Variable = require './variable'
Router = require '../routes/router'
PathBuilder = require '../routes/path_builder'
Navigator = require '../navigator'
Cascade = require '../cascade/cascade'

class Routing
  constructor: (@ace, @navigate) ->
    @uriOutlets = {}
    @variables = []
    @variableFactory = (path, fn) =>
      @variables.push variable = new Variable path, fn, @uriOutlets
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
      keys[key] = 1 for key of route.keys

    @makeURIOutlets Object.keys(keys)
    routes.vars @uriOutlets, @variableFactory, @ace

  push: ->
    return unless @navigator
    @navigator.push()

  enableNavigator: (win=window)->
    return if @navigator
    @enable() unless @router?

    @navigator = new Navigator win
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

