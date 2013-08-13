glob = require 'glob'
path = require 'path'
lib = path.resolve __dirname, '../../../'
async = require 'async'
fs = require 'fs'
fileMemoize = require 'file_memoize'
categorize = require './categorize'

readFile = fileMemoize (filePath, cb) -> fs.readFile filePath, 'utf-8', cb

readExterns = (debugReleaseObj, cb) ->
  readCategory = (category, next) ->
    filePaths = debugReleaseObj[category].sort()
    async.mapSeries filePaths, readFile, (err, codes) ->
      debugReleaseObj[category] = codes.join ';\n' unless err?
      next err
  async.eachSeries Object.keys(debugReleaseObj), readCategory, cb

module.exports = (categories, cb) ->

  glob "#{lib}/_*/**/*.js", (err, filePaths) ->
    return cb err if err?
    filePaths = filePaths.filter (filePath) -> filePath.charAt(0) isnt '.' and -1 is filePath.indexOf '/server/'
    output = categorize categories, filePaths
    async.series [
      (next) -> readExterns output.debug, next
      (next) -> readExterns output.release, next
    ], (err) -> cb err, output


