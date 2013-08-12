BundlerBase = require '../bundler_base'

stream = require 'stream'
async = require 'async'
{defaults} = require '../../../utils/mixin'
EventEmitter = require('events').EventEmitter
# beautify = require('js-beautify').js_beautify

readExterns = require './extern'
makeMvc = require './mvc'
makeLoader = require './loader'

class Bundler extends BundlerBase
  _bundle: (cb) ->
    app = @settings.app

    options = defaults {}, @settings
    globals = @settings.globals
    unless @settings.debug
      options.release = true

    mvcOptions = defaults {}, options
    loaderOptions = defaults {}, options
    loaderOptions.expose = mvcOptions.requires = []

    async.series
      externs: (done) => readExterns done
      mvc: (done) => makeMvc app, routes: @settings['routes'], mvcOptions, done
      loader: (done) => makeLoader app, globals, loaderOptions, done
      (err, obj) =>
        return cb(err) if err?
        @_bundleRelease obj unless @settings.debug
        @_bundleDebug obj
        cb(null)

  _bundleRelease: (obj) ->
    prod = []
    prod.push obj.externs.release, obj.loader.release, obj.mvc.release
    prod = prod.join(';\n')
    @release = [prod]
    return

  _bundleDebug: (obj) ->
    @debug = [obj.externs.debug, obj.loader.debug, obj.mvc.debug]
    return

module.exports = Bundler
