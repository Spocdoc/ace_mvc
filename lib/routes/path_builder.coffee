Auto = require '../cascade/auto'

class PathBuilder extends Auto
  constructor: (@router) ->
    super =>
      params = {}
      for key, outlet of @router.outlets
        params[key] = value if (value = outlet.get())?

      return @_value unless route = @router.matchParams params
      route.format params

module.exports = PathBuilder
