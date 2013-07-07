Ace = require '../index'
Cookies = require '../../cookies'

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    pkg = {}

    Global = require('../../mvc')(pkg).Global
    Global.prototype['cookies'] = new Cookies req, res
    Global.prototype['reset'] = ->
      req.url = '/'
      handle req, res, next
      return

    ace = new Ace pkg, undefined, routes, vars

    ace.router.route req.url
    ace.appendTo $container

    Cascade = ace.pkg.cascade.Cascade

    if Cascade.pending
      Cascade.on 'done', =>
        process.nextTick => cb null, ace
    else
      cb null, ace

    return

