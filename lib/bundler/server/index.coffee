fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
BundlerJS = require './js'
BundlerCSS = require './css'
Url = require '../../url'
async = require 'async'

class Server
  constructor: (settings) ->
    extend @, express()
    delete @handle
    extend @settings, settings

    @debugUris =
      js: []
      css: []

    @releaseUris =
      js: []
      css: []

  boot: (cb) ->
    @js = new BundlerJS @settings
    @css = new BundlerCSS @settings

    for type in ['css','js']
      @[type].on 'update', do (type) => (debug, release) =>
          @debugUris[type] = []
          @releaseUris[type] = []
          if debug
            for hash,i in debug
              @debugUris[type].push "/#{i}d-#{hash}.#{type}"
          if release
            for hash,i in release
              @releaseUris[type].push "/#{i}r-#{hash}.#{type}"
          return

    async.parallel [
      (done) => @js.bundle done
      (done) => @css.bundle done
    ], (err) -> cb(err)

  handle: do ->
    regex = /^\/+(\d+)([dr])-(?:[^/]+)\.(js|css)$/
    
    (req, res, next) ->
      url = (new Url(req.url)).pathname

      unless match = url.match regex
        next()
      else
        if (type = match[3]) is 'css'
          res.setHeader 'Content-Type', 'text/css'
        else
          res.setHeader 'Content-Type', 'text/javascript'

        if match[2] is 'd'
          @[type].writeDebug match[1], res
        else
          @[type].writeRelease match[1], res

      return

module.exports = Server

