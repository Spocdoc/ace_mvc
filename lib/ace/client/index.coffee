Ace = require '../index'
Cookies = require '../../cookies'
router = require '../../router'

module.exports = ->

  Ace['newClient'] = (json, routesConfig, $container) ->
    pkg = {}
    require('../../mvc')(pkg).Global.prototype['cookies'] = new Cookies

    ace = new Ace pkg, json, router.getRoutes(routesConfig), router.getVars(routesConfig), true
    ace['appendTo'] $container
    return
