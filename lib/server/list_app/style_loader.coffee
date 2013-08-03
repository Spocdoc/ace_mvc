path = require 'path'
async = require 'async'
mvcUtils = require '../../mvc/utils'

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
      type = mvcUtils.makeClassName type

      async.waterfall [
        (next) -> stylus.render content, filename: fullPath, linenos:true, next
        (css) ->
          css = wrapInClass(css,type)

          async.parallel
            debug: (done) -> stylus.render css, done
            release: (done) -> stylus.render css, compress: true, done
            cb
      ]




module.exports =
  handles: (ext) -> styleLoaders[ext]?

  compile: (fullPath, type, content, cb) ->
    ext = path.extname(fullPath)[1..]
    styleLoaders[ext](fullPath, type, content, cb)

