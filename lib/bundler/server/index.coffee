fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
Bundler = require './bundler'
Url = require '../../url'

class Server
  constructor: (settings) ->
    # TODO: is this really the only way to extend express. wtf
    extend @, express()
    delete @handle

    extend @settings, settings
    @on 'mount', (app) => @_configure()

  _configure: ->
    @bundler = new Bundler @settings

  handle: do ->
    jsRegex = /^\/+[^/]*\.js/
    localRegex = /^\/+local-/
    externRegex = /^\/+extern-/
    
    (req, res, next) ->
      url = (new Url(req.url)).pathname

      unless url.match jsRegex
        next()
      else
        res.setHeader 'Content-Type', 'text/javascript'

        if url.match localRegex
          res.scriptType = 'local'
        else if url.match externRegex
          res.scriptType = 'extern'

        @bundler.writeScript res

      return

  getUris: (cb) ->
    @bundler.getHash (hash) ->
      cb("/local-#{hash.local}.js", "/extern-#{hash.extern}.js", "/#{hash.prod}.js")
      return
    return

module.exports = Server

