glob = require 'glob'
path = require 'path'
lib = path.resolve __dirname, '../../'
async = require 'async'
fs = require 'fs'

readFile = (filePath, cb) -> fs.readFile filePath, 'utf-8', cb

module.exports = readExterns = (cb) ->
  async.waterfall [
    (next) -> glob './_*/client/**/*.js', cwd: lib, nonegate: true, next
    (files, next) ->
      files.sort()
      files = files.map (filePath) -> path.resolve lib, filePath
      async.mapSeries files, readFile, next
    (codes, next) ->
      next null, codes.join('\n')
  ], cb

