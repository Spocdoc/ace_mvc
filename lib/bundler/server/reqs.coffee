browserifyReqs = require './browserify_reqs'
async = require 'async'

module.exports = (mvc, others, options, cb) ->

  fileMap = {}
  for type in ['view','controller']
    keys = Object.keys mvc[type]
    keys.sort()
    for name,i in keys
      reqName = "#{type[0]}#{i}" # e,g, "v1", "v2", "c1", ...
      fileMap[reqName] = mvc[type][name]

  fileMap[reqName] = fullPath for reqName, fullPath of others

  browserifyReqs fileMap, options, cb

