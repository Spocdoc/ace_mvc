Ace = require '../index'
Cookies = require '../../cookies'

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    pkg = {}
    require('../../mvc')(pkg).Global.prototype['cookies'] = new Cookies req, res

    ace = new Ace undefined, routes, vars, pkg

    ace.reset = ->
      req.url = '/'
      handle req, res, next
      return

    ace.router.route req.url
    ace.appendTo $container

    Cascade = ace.pkg.cascade.Cascade

    if Cascade.pending
      Cascade.on 'done', =>
        process.nextTick => cb null, ace
    else
      cb null, ace

    return

