path = require 'path'
fs = require 'fs'

handledExtensions = (path.basename file, path.extname file for file in fs.readdirSync(__dirname) when !/^(?:\.|index\.)/.test file)

module.exports = (filePath, name, globals) ->
  require("./#{path.extname(filePath)?.substr(1)}")(filePath, name, globals)

module.exports.isTemplate = (filePath) ->
  path.extname(filePath)?.substr(1) in handledExtensions

