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
    extend @, express()
    extend @settings, settings

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
          fn(@settings[name], this) if typeof (fn = require filePath) is 'function'
        next()
    ], cb

  boot: (cb) ->
    app = @parent
    process.on 'SIGINT', -> process.exit(1)

    lib = path.resolve __dirname, '../../'
    async.waterfall [
      (done) => @_loadExterns lib, done
      (done) => @_loadServerFiles lib, done
      (done) =>
        listMvc = require '../../mvc/server/list_mvc'
        listMvc @settings['root'], done
      (mvc, done) =>
        @settings.mvc = mvc

        extend @settings['bundler'],
          mvc: mvc
          'debug': @settings['debug']
          'routes': @settings['routes']
          'globals':
            'Ace': path.resolve(__dirname, '../../ace')

        app.use @bundler = new Bundler @settings['bundler']
        @bundler.boot done

      (done) =>
        app.use @aceApp = new App @bundler, @settings
        @aceApp.boot done
    ], cb

module.exports = Main

