closurify = require 'closurify'
async = require 'async'
quote = require '../../../utils/quote'

module.exports = (app, expose, options, cb) ->
  files = []

  file = ""
  for name, filePath of expose
    file += "window.Ace[#{quote(name)}] = require(#{quote(filePath)});"
    files.push filePath

  for type in ['model','view','controller']
    for name, filePath of app[type]
      files.push filePath

  closurify file,
    release: options.release && 'uglify'
    expose: files
    requires: options.requires
    cb

