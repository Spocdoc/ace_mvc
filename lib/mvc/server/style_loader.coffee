path = require 'path'
async = require 'async'
utils = require '../utils'

# note: in principle this could be modularized so each style type is in a
# separate file that's `require`'d as needed

styleLoaders =
  'styl': do ->
    wrapInClass = (styl, type) ->
      if type
        lines = []
        lines.push ".#{type}"
        lines.push "  #{line}" for line in styl.split '\n'
        lines.join '\n'
      else
        styl

    stylus = require 'stylus'

    (fullPath, type, content, cb) ->
      type = utils.makeClassName type

      async.parallel
        debug: (done) ->
          stylus.render wrapInClass(content,type), filename: fullPath, compress: false, linenos:true, done
        release: (done) ->
          stylus.render wrapInClass(content,type), filename: fullPath, compress: true, linenos: false, done
        cb

module.exports =
  handles: (ext) -> styleLoaders[ext]?

  compile: (fullPath, type, content, cb) ->
    ext = path.extname(fullPath)[1..]
    styleLoaders[ext](fullPath, type, content, cb)

