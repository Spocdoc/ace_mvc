fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../utils/mixin'
BundlerJS = require './js'
BundlerCSS = require './css'
Url = require '../../utils/url'
async = require 'async'

hash = (str) -> require('crypto').createHash('sha1').update(str).digest("hex")

class Server
  constructor: (settings) ->
    extend @, express()
    delete @handle
    extend @settings, settings

    @debugUris =
      js: {}
      css: {}

    @releaseUris =
      js: {}
      css: {}

    @releaseCategories = {}

  boot: (cb) ->
    @js = new BundlerJS @settings
    @css = new BundlerCSS @settings

    for type in ['css','js']
      @[type].on 'update', do (type) =>
        (debug, release) =>

          @debugUris[type] = {}
          @releaseUris[type] = {}

          for category, hashes of debug
            arr = @debugUris[type][category] = []
            for fileHash, i in hashes
              arr.push "/debug-#{type}-#{category}-#{i}-#{fileHash}.#{type}"

          for category, hashes of release
            arr = @releaseUris[type][category] = []
            @releaseCategories[catHash = hash(category).substr(0,24)] = category

            for fileHash, i in hashes
              arr.push "/#{i}-#{catHash}#{fileHash.substr(0,24)}.#{type}"

          return

    async.parallel [
      (done) => @js.bundle done
      (done) => @css.bundle done
    ], (err) -> cb(err)

  handle: do ->
    debugRegex = /^\/+debug-(js|css)-(\S+)-(\d+)-(?:[^/]+)\.(js|css)/
    releaseRegex = /^\/+(\d+)-([^/]{24})(?:[^/]{24})\.(js|css)/
    
    (req, res, next) ->
      url = (new Url(req.url, slashes: false)).pathname

      if m = debugRegex.exec url
        debugRelease = "debug"
        type = m[1]
        category = m[2]
        number = m[3]
      else if (m = releaseRegex.exec url) and category = @releaseCategories[m[2]]
        debugRelease = "release"
        type = m[3]
        number = m[1]
      else
        return next()

      if type is 'css'
        res.setHeader 'Content-Type', 'text/css'
      else
        res.setHeader 'Content-Type', 'text/javascript'

      @[type].write debugRelease, category, number, res
      return

module.exports = Server

