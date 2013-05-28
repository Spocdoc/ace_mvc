path = require 'path'
async = require 'async'

# note: in principle this could be modularized so each style type is in a
# separate file that's `require`'d as needed

styleLoaders =
  'styl': do ->
    wrapInClass = (styl, name) ->
      if name
        lines = []
        lines.push ".#{name}"
        lines.push "  #{line}" for line in styl.split '\n'
        lines.join '\n'
      else
        styl

    stylus = require 'stylus'

    (fullPath, name, content, cb) ->
      name = name.replace '/', '-'

      async.parallel
        debug: (done) ->
          stylus.render wrapInClass(content,name), filename: fullPath, compress: false, linenos:true, done
        release: (done) ->
          stylus.render wrapInClass(content,name), filename: fullPath, compress: true, linenos: false, done
        cb

module.exports =
  handles: (ext) -> styleLoaders[ext]?

  compile: (fullPath, name, content, cb) ->
    ext = path.extname(fullPath)[1..]
    styleLoaders[ext](fullPath, name, content, cb)

