Url = require '../url'
Cascade = require '../cascade/cascade'
Route = require './route'

class Router extends Array
  constructor: (@outlets) ->
    super

  # invokes parameter callbacks and callbacks for the route if matched
  # @param url [String]
  # @returns first matching Route
  route: (url) ->
    url = new Url(url, slashes: false)
    return null unless ret = @matchPath url.pathname, url.hash
    [route,params] = ret

    Cascade.Block =>
      @outlets[spec.key].set(params[spec.key]) for spec in route.specs
      @outlets[route.qsKey].set(url.query) if route.qsKey?
      @outlets[k].set(v) for k,v of route.outletHash
      return

    return route

  matchPath: (pathname, hash) ->
    for route in this
      return [route, params] if params = route.match pathname, hash

  matchParams: (params) ->
    for route in this
      return route if route.matchParams params

module.exports = Router
