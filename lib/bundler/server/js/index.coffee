BundlerBase = require '../bundler_base'

stream = require 'stream'
async = require 'async'
{defaults} = require '../../../mixin'
EventEmitter = require('events').EventEmitter

readExterns = require './extern'
makeReqs = require './reqs'
makeLoader = require './loader'

class Bundler extends BundlerBase
  _bundle: (cb) ->
    mvc = @settings.mvc

    reqs =
      'routes': @settings['routes']

    options = defaults {}, @settings
    globals = @settings.globals
    unless @settings.debug
      options.release = true

    async.parallel
      externs: (done) -> readExterns done
      requires: (done) -> makeReqs mvc, reqs, options, done
      loader: (done) -> makeLoader mvc, globals, options, done
      (err, obj) =>
        return cb(err) if err?
        @_bundleRelease obj unless @settings.debug
        @_bundleDebug obj
        cb(null)

  _bundleRelease: (obj) ->
    prod = []
    prod.push obj.externs.release, obj.requires.release, obj.loader.release
    prod = prod.join('\n')
    @release = [prod]
    return

  _bundleDebug: (obj) ->
    @debug = [obj.externs.debug, obj.requires.debug, obj.loader.debug]
    return

module.exports = Bundler
