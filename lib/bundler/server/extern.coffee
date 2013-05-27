glob = require 'glob'
path = require 'path'
lib = path.resolve __dirname, '../../'
async = require 'async'
fs = require 'fs'

readFile = (filePath, cb) -> fs.readFile filePath, 'utf-8', cb

readExterns = (aGlob, cb) ->
  async.waterfall [
    (next) -> glob aGlob, cwd: lib, nonegate: true, next
    (files, next) ->
      files.sort()
      files = files.map (filePath) -> path.resolve lib, filePath
      async.mapSeries files, readFile, next
    (codes, next) ->
      next null, codes.join('\n')
  ], cb

module.exports = (cb) ->
  async.parallel
    debug: (done) -> readExterns './_*/client/**/!(release*).js', done
    release: (done) -> readExterns './_*/client/**/!(debug*).js', done
    cb

