stream = require 'stream'
EventEmitter = require('events').EventEmitter

hash = (str) -> require('crypto').createHash('sha1').update(str).digest("hex")

class BundlerBase extends EventEmitter
  constructor: (@settings) ->

  writeDebug: (number, stream) ->
    stream.end @debug[number]
    return

  writeRelease: (number, stream) ->
    stream.end @release[number]
    return

  didBundle: ->
    @emit 'update', @hashes.debug, @hashes.release
    return

  bundle: (cb) ->
    return if @bundling
    @bundling = true

    @_bundle (err) =>
      if err?
        console.error err
        @bundling = false
      else
        @hashes = {}
        @hashes.release = @release.map hash if @release?
        @hashes.debug = @debug.map hash
        @bundling = false
        @didBundle()

      cb(err)
      return
    return


module.exports = BundlerBase
