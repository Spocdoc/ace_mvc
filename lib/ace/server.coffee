Ace = require './index'

addParamHooks = (app, routes) ->
  keys = {}
  keys[spec.name] = 1 for spec in route.keys for route in routes
  for key of keys
    app.param key, (req, res, next, value, name) ->
      res.ace.uriOutlets[name]?.set(value)
      next()
  return Object.keys(keys)

# @param app connect/express app
# @param routes path to local routes file
module.exports = (app, routesPath='./routes') ->
  routes = require routesPath

  app.all '/', (req, res, next) ->
    ace = res.ace = new Ace
    routing = ace.routing
    routing.makeURIOutlets uriKeys
    routes.vars res.ace.routing.uriOutlets, routing.variableFactory, ace
    next()

  routesStart = app.routes.get.length

  routes.routes (uri, qs, outlets) ->
    [outlets,qs] = [qs, undefined] if not outlets and typeof qs isnt 'string'

    uri = uri.substr(0,hash) if ~(hash = uri.indexOf('#'))

    app.get uri, (req, res, next) ->
      res.ace.uriOutlets[k].set(v) for k,v of outlets
      res.ace.uriOutlets[qs].set(req.query) if qs

      # TODO: now generate the response

    return

  uriKeys = addParamHooks app, app.routes.get[routesStart..]

