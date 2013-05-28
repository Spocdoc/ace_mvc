browserify = require 'browserify'
coffeeify = require 'coffeeify'
mold = require 'mold-source-map'
ug = require 'uglify-js'
async = require 'async'
stream = require 'stream'

uglify = (code, sourceMap) ->
  toplevel = ug.parse code
  toplevel.figure_out_scope()
  toplevel = toplevel.transform ug.Compressor({})
  toplevel.figure_out_scope()
  toplevel.compute_char_frequency()
  toplevel.mangle_names noFunArgs: true
  stream = undefined

  unless sourceMap
    stream = ug.OutputStream()
  else
    map = ug.SourceMap orig: sourceMap
    stream = ug.OutputStream source_map: map

  toplevel.print stream
  return {
    code: ''+stream
    sourceMap: ''+map
  }

class BrowserifyString extends stream.Writable
  constructor: (@callback) ->
    super
    @code = []

  _write: (chunk, encoding, callback) ->
    [encoding,callback] = ['utf8', encoding] unless callback?
    chunk = chunk.toString encoding unless typeof chunk is 'string'
    @code.push chunk
    callback()

  end: (chunk, encoding, callback) ->
    @_write chunk, encoding, callback if chunk
    @callback null, @code.join('')

module.exports = (fileMap, options, cb) ->
  if typeof options is 'function'
    [cb,options] = [options, {}]

  async.waterfall [
    (next) ->
      sourceMap = undefined

      brow = browserify()

      for expose, fullPath of fileMap
        brow.require fullPath, expose: expose

      brow.transform(coffeeify)
        .bundle({debug: true})
        .pipe(mold.transform (sourcemap, cb) ->
          sourceMap = sourcemap.toObject()
          cb ''
        )
        .pipe(new BrowserifyString (err, code) -> next(err, code, sourceMap))

    (code, sourceMap, next) ->
      sourceMapB64 = new Buffer(JSON.stringify sourceMap).toString('base64')
      debug = code + "/*\n//@ sourceMappingURL=data:application/json;base64,#{sourceMapB64}\n*/"
      release = uglify(code).code
      next null, {debug, release}
  ], cb
