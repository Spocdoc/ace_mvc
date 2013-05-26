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

  start: ->
    @bundler = new Bundler @settings

  handle: do ->
    jsRegex = /^\/+(\d+)([dr])-([^/]+)\.js/
    
    (req, res, next) ->
      url = (new Url(req.url)).pathname

      unless match = url.match jsRegex
        next()
      else
        res.setHeader 'Content-Type', 'text/javascript'

        if match[2] is 'd'
          @bundler.writeDebug match[1], res
        else
          @bundler.writeRelease match[1], res

      return

  getUris: (cb) ->
    @bundler.getHashes (debug, release) ->
      debugUris = []
      releaseUris = []

      if debug
        for hash,i in debug
          debugUris.push "/#{i}d-#{hash}.js"

      if release
        for hash,i in release
          releaseUris.push "/#{i}r-#{hash}.js"

      cb debugUris, releaseUris
      return
    return

module.exports = Server

