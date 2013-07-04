Ace = require '../index'
Cookies = require '../../cookies'
router = require '../../router'

module.exports = ->

  Ace['newClient'] = (json, routesConfig, $container) ->
    pkg = {}
    require('../../mvc')(pkg).Global.prototype['cookies'] = new Cookies

    ace = new Ace json, router.getRoutes(routesConfig), router.getVars(routesConfig), pkg

    ace.router.enableNavigator()
    ace.router.route ace.router.navigator.url

    ace['appendTo'] $container
    return
