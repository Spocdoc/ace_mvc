BundlerBase = require '../bundler_base'

class Bundler extends BundlerBase
  _bundle: (cb) ->
    prod = []
    @debug = []

    for name, {debug, release} of @settings.app['style']
      prod.push release
      @debug.push debug

    @release = [prod.join('')]
    cb(null)

module.exports = Bundler
