class Ace

  constructor: (@pkg, json, routes, vars, useNavigator) ->
    pkg.ace = ace = @ace = this
    @_name = 'ace'

    OJSON = pkg.ojson || require('../utils/ojson')(pkg)
    pkg.cascade || require('../cascade')(pkg)
    pkg.mvc || require('../mvc')(pkg)
    pkg.router || require('../router')(pkg)

    @pkg.mvc.Model.fromJSON json if json

    @router = new pkg.Router routes, vars, useNavigator
    @vars = @router.vars

  toJSON: -> @pkg.mvc.Model.toJSON()

  toString: -> "Ace [#{@_name}]"

  'appendTo': ($root) ->
    @pkg.mvc.Template.$root = $root
    controller = new @pkg.mvc.Controller['body'] this
    controller['appendTo'] $root
    return

module.exports = Ace
