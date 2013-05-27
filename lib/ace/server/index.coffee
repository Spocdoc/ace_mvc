fs = require 'fs'
path = require 'path'
express = require('express')
glob = require 'glob'
async = require 'async'
{extend} = require '../../mixin'
App = require './app'
Bundler = require '../../bundler/server'

# express sets route, parent
class Main
  constructor: (settings) ->
    # TODO: is this really the only way to extend express. wtf
    extend @, express()

    extend @settings, settings
    @on 'mount', (app) => @_configure(app)

  _loadExterns: (lib, cb) ->
    async.waterfall [
      (next) -> glob "#{lib}/_*/server/*", next
      (filePaths, next) ->
        filePaths.map (filePath) -> require filePath
        next()
    ], cb

  _loadServerFiles: (lib, cb) ->
    async.waterfall [
      (next) -> glob "#{lib}/!(_*|ace|bundler)/server", nonegate: true, next
      (filePaths, next) =>
        filePaths.map (filePath) =>
          name = path.basename path.resolve filePath, '..'
          fn(this, @settings[name]) if typeof (fn = require filePath) is 'function'
        next()
    ], cb

  _configure: (app) ->
    process.on 'SIGINT', -> process.exit(1)

    lib = path.resolve __dirname, '../../'
    async.series [
      (done) => @_loadExterns lib, done
      (done) => @_loadServerFiles lib, done
      (done) =>
        bundler = new Bundler @settings.bundler
        bundler.set 'mvc', @settings['mvc']
        app.use bundler

        @settings._bundler = bundler

        aceApp = new App @settings
        app.use aceApp
    ]

module.exports = Main

