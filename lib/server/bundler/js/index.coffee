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
      externs: (done) => readExterns @settings.categories, done
      mvc: (done) => makeMvc app, routes: @settings['routes'], mvcOptions, done
      loader: (done) => makeLoader app, globals, loaderOptions, done
      (err, obj) =>
        return cb(err) if err?

        @_nonstandard = {}
        @_nonstandard[category] = 1 for category in (@settings.categories?.nonstandard ? [])

        @_bundleRelease obj unless @settings.debug
        @_bundleDebug obj
        cb(null)

  _bundleRelease: (obj) ->
    prod = {}
    tmp = []

    for category, externCode of obj.externs.release
      if @_nonstandard[category]
        prod[category] = [externCode]
      else
        i = 0
        tmp[i++] = externCode
        tmp[i++] = obj.loader.release
        tmp[i++] = obj.mvc.release
        prod[category] = [tmp.join ';\n']

    @release = prod
    return

  _bundleDebug: (obj) ->
    @debug = {}

    for category, externCode of obj.externs.debug
      if @_nonstandard[category]
        @debug[category] = [externCode]
      else
        @debug[category] = [externCode, obj.loader.debug, obj.mvc.debug]

    return

module.exports = Bundler
