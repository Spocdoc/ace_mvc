require 'debug-fork'
template = require './lib/template'

if process.env.NODE_ENV is 'production'
  module.exports = require './prod'
  module.exports.browserExpressions = ['ios', '-ie<8']
else
  module.exports = require './dev'
  # module.exports.browserExpressions = ['ios', '-ie<8']
  module.exports.browserExpressions = ['ios', '']

module.exports.initializer = """if (window.Ace && window.aceArgs) { new Ace(window.aceArgs); }"""

module.exports.isTemplate = template.isTemplate


