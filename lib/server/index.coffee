fs = require 'fs'
path = require 'path'
express = require 'express'
connect = require 'connect'
glob = require 'glob'
async = require 'async'
{extend} = require '../utils/mixin'

# express sets route, parent
module.exports = class Server
  constructor: (settings) ->
    extend @, express()
    extend @settings, settings

  _loadExterns: (lib, cb) ->
    async.waterfall [
      (next) ->
        async.concat ["#{lib}/_*/**/server/*","#{lib}/_*/!(client|server)"], glob, next
      (filePaths, next) ->
        filePaths.map (filePath) -> require filePath
        next()
    ], cb

  _loadServerFiles: (lib, cb) ->
    async.waterfall [
      (next) -> glob "#{lib}/!(_*)/**/server", nonegate: true, next
      (filePaths, next) =>
        filePaths.map (filePath) =>
          name = path.relative(lib, filePath).split(path.sep)[0]
          fn(@settings[name], this) if typeof (fn = require filePath) is 'function'
        next()
    ], cb

  boot: (cb) ->
    process.on 'SIGINT', -> process.exit(1)

    lib = path.resolve __dirname, '../'
    async.waterfall [
      (done) => @_loadExterns lib, done
      (done) => @_loadServerFiles lib, done
      (done) =>
        listApp = require './list_app'
        listApp @settings['root'], done
      (app, done) =>
        Bundler = require './bundler'
        @settings.app = app

        extend @settings['bundler'],
          app: app
          'debug': @settings['debug']
          'routes': @settings['routes']
          'globals':
            'Ace': path.resolve(__dirname, "#{lib}/ace")

        @parent.use connect.multipart()
        @parent.use @bundler = new Bundler @settings['bundler']
        @bundler.boot done

      (done) =>
        App = require './app'
        @parent.use @aceApp = new App @bundler, @settings
        @aceApp.boot done
    ], cb

