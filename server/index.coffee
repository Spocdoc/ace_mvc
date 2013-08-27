Module = require 'module'
glob = require 'glob'

Module.prototype.require = do ->
  orig = Module.prototype.require
  (path, side) -> orig path unless side is 'client'

require file for file in glob.sync "../vendor/**/server/*"

if process.ENV.NODE_ENV is 'production'
  return require './prod'
else
  return require './dev'

