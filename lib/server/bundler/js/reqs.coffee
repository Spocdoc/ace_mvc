closurify = require 'closurify'
async = require 'async'

module.exports = (app, others, options, cb) ->

  files = []
  expose = {}
  for type in ['model','view','controller']
    for name,i in Object.keys(app[type]).sort()
      reqName = "#{type[0]}#{i}" # e,g, "v1", "v2", "c1", ...
      files.push expose[reqName] = app[type][name]

  for reqName, filePath of others
    files.push expose[reqName] = filePath

  closurify files,
    release: options.release && 'uglify'
    expose: expose
    cb

