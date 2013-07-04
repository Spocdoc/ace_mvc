glob = require 'glob'
path = require 'path'
lib = path.resolve __dirname, '../../../'
async = require 'async'
closurify = require 'closurify'

quote = require '../../../utils/quote'

module.exports = makeLoader = (app, globals, options, cb) ->
  if typeof options is 'function'
    [cb,options] = [options, {}]

  async.waterfall [
    (next) -> glob './!(_*)/**/client', cwd: lib, nonegate: true, next

    (dirs, next) ->
      dirs.sort()

      script = []
      # there are no exports
      # script.push "require(#{quote(path.resolve(lib,'exports'))});"
      script.push "var r;"
      for p in dirs
        name = p.substr(2).replace(/\/.*$/,'')
        script.push """
        if (typeof (r = require(#{quote(path.resolve(lib,p))})) === 'function') {
          r(#{options[name] && JSON.stringify(options[name]) || ''});
        };
        """

      # global entry points
      for n,p of globals
        script.push "global[#{quote(n)}] = require(#{quote(p)});"

      # local Template, View, etc.
      for type in ['Template','View','Controller','Model']
        p = path.resolve(lib, "./mvc/#{type.toLowerCase()}")
        script.push "var #{type} = require(#{quote(p)});"

      # build templates
      for name, dom of app['template']
        script.push "Template.add(#{quote(name)}, #{quote(dom)});"

      # build mvc
      for type in ['View','Controller','Model']
        for name,i in Object.keys(app[type.toLowerCase()]).sort()
          reqName = "#{type[0].toLowerCase()}#{i}" # e,g, "v1", "v2", "c1", ...
          # the require(path,1) is a hack so it doesn't get replaced in closurify
          script.push "#{type}.add(#{quote(name)}, require(#{quote(reqName)},1));"

      # finish mvc
      for type in ['View','Controller','Model']
        script.push """#{type}.finish();"""

      closurify script.join('\n'), options, (err, obj) ->
        if release = obj?.release
          console.error release[1]
          release = release[0]

        next err,
          debug: obj?.debug
          release: release
  ], cb

