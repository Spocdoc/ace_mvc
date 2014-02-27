_ = require 'lodash-fork'
jade = require 'jade'

module.exports = (filePath, name, globals) ->
  jade.compile(_.readFileSync(filePath), filename: filePath)(globals)



