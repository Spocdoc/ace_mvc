stream = require 'stream'
EventEmitter = require('events').EventEmitter

hash = (str) -> require('crypto').createHash('sha1').update(str).digest("hex")

class BundlerBase extends EventEmitter
  constructor: (@settings) ->

  write: (debugRelease, category, number, stream) ->
    if code = @[debugRelease][category]?[number]
      stream.end code
    else
      stream.end()
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
        @hashes =
          debug: {}
          release: {}

        @hashes.release[k] = arr.map hash for k,arr of @release
        @hashes.debug[k] = arr.map hash for k,arr of @debug

        @bundling = false
        @didBundle()

      cb(err)
      return
    return


module.exports = BundlerBase
