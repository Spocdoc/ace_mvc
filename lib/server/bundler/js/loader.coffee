glob = require 'glob'
path = require 'path'
lib = path.resolve __dirname, '../../../'
async = require 'async'
closurify = require 'closurify'
fs = require 'fs'

quote = require '../../../utils/quote'

getInode = (filePath, cb) ->
  fs.stat filePath, (err, stat) ->
    return cb(err) if err?
    cb null, ""+stat.ino

module.exports = makeLoader = (app, globals, options, cb) ->
  if typeof options is 'function'
    [cb,options] = [options, {}]

  script = []

  async.waterfall [
    (next) -> glob './!(_*)/**/client', cwd: lib, nonegate: true, next

    (dirs, next) ->
      dirs.sort()

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
      for className in ['Template','Model','View','Controller']
        p = path.resolve(lib, "./mvc/#{className.toLowerCase()}")
        script.push "var #{className} = require(#{quote(p)});"

      # build templates
      for name, dom of app['template']
        script.push "Template.add(#{quote(name)}, #{quote(dom)});"
      script.push "Template.finish();"

      # build mvc
      mvc = []
      for className in ['Model','View','Controller']
        for name, filePath of app[className.toLowerCase()]
          mvc.push {name, className, filePath}

      mvcToInode = (entry, cb) ->
        getInode entry.filePath, (err, inode) ->
          return cb err if err?
          entry.inode = inode
          cb null, entry

      async.mapLimit mvc, 8, mvcToInode, next

    (mvc, next) ->
      script.push "global['Ace'].initMVC = function () {"
      for entry in mvc
        script.push "#{entry.className}.add(#{quote(entry.name)}, window['req#{entry.inode}']);"
      for className in ['Model','View','Controller']
        script.push "#{className}.finish();"
      script.push "};"

      closurify script.join('\n'), options, (err, obj) ->
        if release = obj?.release
          console.error release[1]
          release = release[0]

        next err,
          debug: obj?.debug
          release: release
  ], cb

