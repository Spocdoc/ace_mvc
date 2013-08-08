glob = require 'glob'
path = require 'path'
lib = path.resolve __dirname, '../../../'
async = require 'async'
fs = require 'fs'

readFile = (filePath, cb) -> fs.readFile filePath, 'utf-8', cb

readExterns = (aGlob, cb) ->
  async.waterfall [
    (next) -> glob aGlob, cwd: lib, nonegate: true, next
    (files, next) ->
      files = files.filter (filePath) -> !~filePath.indexOf '/server/'
      files.sort()
      files = files.map (filePath) -> path.resolve lib, filePath
      async.mapSeries files, readFile, next
  ], cb

module.exports = (cb) ->
  async.parallel
    debug: (done) ->
      async.concat ['./_*/client/**/!(release*).js', './_*/!(client|server)'], readExterns, (err, codes) ->
        return done err if err?
        done null, codes.join('\n')
    release: (done) ->
      async.concat ['./_*/client/**/!(debug*).js', './_*/!(client|server)'], readExterns, (err, codes) ->
        return done err if err?
        done null, codes.join('\n')
    cb

