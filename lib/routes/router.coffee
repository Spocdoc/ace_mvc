Url = require '../url'
Cascade = require '../cascade/cascade'
Route = require './route'
debug = global.debug 'ace:routing'

class Router
  constructor: (@outlets) ->
    @length = 0

  push: (arg) ->
    @[@length++] = arg
    return

  # invokes parameter callbacks and callbacks for the route if matched
  # @param url [String]
  # @returns first matching Route
  route: (url) ->
    debug "Routing #{url}"
    url = new Url(url, slashes: false) unless url instanceof Url
    unless ret = @matchPath url.pathname, url.hash
      debug "no match for #{url}"
      return null
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
