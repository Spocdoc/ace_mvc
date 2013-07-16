Ace = require '../index'
Cookies = require '../../cookies'

module.exports = ->

  Ace.newServer = (req, res, next, $container, routes, vars, cb) ->
    pkg = {}

    sock = pkg.socket = global.io.connect '/'

    Global = require('../../mvc')(pkg).Global
    cookies = Global.prototype['cookies'] = new Cookies req, res
    Global.prototype['reset'] = ->
      req.url = '/'
      handle req, res, next
      return

    sock.emit 'cookies', cookies.toJSON()

    ace = new Ace pkg, undefined, routes, vars

    ace.router.route req.url
    ace.appendTo $container

    Cascade = ace.pkg.cascade.Cascade

    done = =>
      sock.emit 'disconnect'
      json = ace.toJSON()
      cb null, json

    if Cascade.pending
      Cascade.on 'done', => process.nextTick done
    else
      done()

    return

