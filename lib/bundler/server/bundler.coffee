fs = require 'fs'
stream = require 'stream'
path = require 'path'
queue = require '../../queue'
async = require 'async'
{defaults} = require '../../mixin'

listMvc = require '../../mvc/server/list_mvc'
readExterns = require './extern'
makeReqs = require './reqs'
makeLoader = require './loader'

hash = (str) -> require('crypto').createHash('sha1').update(str).digest("hex")

class Bundler
  constructor: (@settings) ->
    @dq = queue() # debug script queue
    @rq = queue() # release script queue
    @hq = queue() # hash queue
    @bundle()

  getHashes: (cb) ->
    if @hashes?
      cb @hashes.debug, @hashes.release
    else
      @hq [cb]
    return

  writeDebug: (number, stream) ->
    if @scripts?
      stream.end @scripts.debug[number]
    else
      @dq [number, stream]
    return

  writeRelease: (number, stream) ->
    if @scripts?
      stream.end @scripts.release[number]
    else
      @rq [number, stream]
    return

  didBundle: ->
    @writeDebug args... while args = @rq()
    @writeRelease args... while args = @dq()
    @getHashes args... while args = @hq()
    return

  _bundle: (cb) ->
    mvc = listMvc(@settings['mvc']['templates'], @settings['mvc']['files'])
    reqs =
      'routes': @settings['routes']

    options = defaults {}, @settings
    globals = @settings.globals
    unless @settings.debug
      options.release = true

    async.parallel
      externs: (next) -> readExterns next
      requires: (next) -> makeReqs mvc, reqs, options, (err, debug, release) ->
        next(err, {debug, release})
      loader: (next) -> makeLoader mvc, globals, options, (err, debug, release) ->
        next(err, {debug, release})
      cb

  _bundleRelease: (obj) ->
    prod = []
    prod.push obj.externs, obj.requires.release, obj.loader.release
    prod = prod.join('\n')
    @scripts.release = release = [prod]
    @hashes.release = release.map hash
    return

  _bundleDebug: (obj) ->
    @scripts.debug = debug = [obj.externs, obj.requires.debug, obj.loader.debug]
    @hashes.debug = debug.map hash
    return

  bundle: ->
    return if @bundling
    @bundling = true

    @_bundle (err, obj) =>
      if err?
        console.error err
        @bundling = false
      else
        @scripts = {}
        @hashes = {}

        @_bundleRelease obj unless @settings.debug
        @_bundleDebug obj

        @bundling = false
        @didBundle()

      return
    return


module.exports = Bundler
