class Ace

  constructor: (json, routes, vars, pkg={}) ->
    @pkg = pkg
    pkg.ace = ace = @ace = this
    @_name = 'ace'

    OJSON = pkg.ojson || require('../utils/ojson')(pkg)
    pkg.cascade || require('../cascade')(pkg)
    pkg.mvc || require('../mvc')(pkg)
    pkg.router || require('../router')(pkg)

    OJSON.fromOJSON json if json

    @router = new pkg.Router routes, vars

  toJSON: -> @pkg.ojson.toOJSON @pkg.mvc.Model.allModels()

  # TODO a reset could simply remove all the models from the cache and load the index
  reset: -> global.location.reload()

  toString: -> "Ace [#{@_name}]"

  'appendTo': ($root) ->
    @pkg.mvc.Template.$root = $root

    unless @root
      Outlet = @pkg.cascade.Outlet
      @root = new Outlet
      @root.setDir Outlet.root

    @root.set controller = new @pkg.mvc.Controller['body'] this
    controller['appendTo'] $root
    return

module.exports = Ace
