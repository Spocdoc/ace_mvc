Ace = require '../index'
Cookies = require '../../cookies'
router = require '../../router'

module.exports = ->

  Ace['newClient'] = (json, routesConfig, $container) ->
    pkg = {}
    sock = pkg.socket = global.io.connect '/'
    cookies = require('../../mvc')(pkg).Global.prototype['cookies'] = new Cookies
    sock.emit 'cookies', cookies.toJSON()

    ace = new Ace pkg, json, router.getRoutes(routesConfig), router.getVars(routesConfig), true
    ace['appendTo'] $container
    return
