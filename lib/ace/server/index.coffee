fs = require 'fs'
path = require 'path'
express = require('express')
{extend} = require '../../mixin'
App = require './app'
Bundler = require '../../bundler/server'

directories = (path) ->
  dir for dir in fs.readdirSync path when fs.statSync("#{path}/#{dir}").isDirectory()

# express sets route, parent
class Main
  constructor: (settings) ->
    # TODO: is this really the only way to extend express. wtf
    extend @, express()

    extend @settings, settings
    @on 'mount', (app) => @_configure(app)

  _configure: (app) ->
    process.on 'SIGINT', -> process.exit(1)

    # load everything in server directories
    basePath = path.resolve(__dirname, '../../')
    for name in directories(basePath) when fs.existsSync(p="#{basePath}/#{name}/server") and !(name in ['ace','bundler'])
      fn(this, @settings[name]) if typeof (fn = require(p)) is 'function'

    bundler = new Bundler @settings.bundler
    bundler.set 'mvc', @settings['mvc']
    app.use bundler

    @settings._bundler = bundler

    aceApp = new App @settings
    app.use aceApp

module.exports = Main

