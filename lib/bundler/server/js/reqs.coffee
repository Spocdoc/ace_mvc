closurify = require 'closurify'
async = require 'async'

module.exports = (mvc, others, options, cb) ->

  files = []
  expose = {}
  for type in ['view','controller']
    keys = Object.keys mvc[type]
    keys.sort()
    for name,i in keys
      reqName = "#{type[0]}#{i}" # e,g, "v1", "v2", "c1", ...
      filePath = mvc[type][name]
      expose[reqName] = filePath
      files.push filePath

  for reqName, filePath of others
    expose[reqName] = filePath
    files.push filePath

  closurify files,
    release: options.release && 'uglify'
    expose: expose
    cb

