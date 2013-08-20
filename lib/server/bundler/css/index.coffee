BundlerBase = require '../bundler_base'

module.exports = class Bundler extends BundlerBase
  _bundle: (cb) ->
    @debug = {standard: debugs = []}
    @release = {standard: releases = []}

    for name, {debug, release} of @settings.app['style']
      debugs.push debug
      releases.push release

    @release.standard = [releases.join ' ']
    cb(null)
