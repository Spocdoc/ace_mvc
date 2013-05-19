fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
Bundler = require './bundler'


class Server
  constructor: (settings) ->
    # TODO: is this really the only way to extend express. wtf
    extend @, express()
    delete @handle

    extend @settings, settings
    @on 'mount', (app) => @_configure()

  _configure: ->
    @bundler = new Bundler @settings.debug

  handle: (req, res, next) ->
    req.scripts = @bundler
    return next() unless req.url.match /^\/[^/]*\.js/
    res.setHeader 'Content-Type', 'text/javascript'
    @bundler.writeScript res

module.exports = Server

