browserify = require 'browserify'
coffeeify = require 'coffeeify'
fs = require 'fs'
stream = require 'stream'
uglifier = new (require('browserify-uglify'))
path = require 'path'
queue = require '../../queue'
async = require 'async'

hash = (str) ->
   require('crypto').createHash('sha1').update(str).digest("hex")

directories = (basePath, cb) ->
  async.waterfall [
    (next) -> fs.readdir basePath, (err, files) -> next(err,files)
    (files, next) ->
      async.mapSeries files.map((file) -> "#{basePath}/#{file}"), fs.stat, (err, stats) ->
        return next(err) if err?
        dirs = []
        for stat,i in stats when stat.isDirectory()
          dirs.push files[i]
        next(err, dirs)
  ], cb
  return

clientFiles = (basePath, cb) ->
  async.waterfall [
    (next) -> directories basePath, (err,dirs) -> next(err,dirs)
    (dirs, next) -> async.filter dirs, ((a, b) -> fs.exists("#{basePath}/#{a}/client",b)), (cl) -> next(null, cl)
    (dirs, next) ->
      next null, (dirs.map (a) -> "#{a}/client")
  ], cb

clientExterns = (basePath, cb) ->
  async.waterfall [
    (next) -> directories basePath, (err,dirs) -> next(err,dirs)
    (dirs, next) -> async.filter dirs, ((a, b) -> fs.exists("#{basePath}/#{a}/client/extern",b)), (cl) -> next(null, cl)
    (dirs, next) ->
      async.mapSeries dirs.map((dir) -> "#{basePath}/#{dir}/client/extern"), fs.readdir, (err, fileses) ->
        return next(err) if err?
        result = []
        for files,i in fileses
          for file in files
            result.push "#{basePath}/#{dirs[i]}/client/extern/#{file}"
        next(err, result)
  ], cb

class Bundler
  constructor: (@debug=false) ->
    @bundle()
    @sq = queue()
    @hq = queue()

  getHash: (cb) ->
    if @hash?
      cb(@hash)
    else
      @hq(cb)
    return

  writeScript: (res) ->
    if @script?
      res.end @script
    else
      @sq(res)
    return

  didBundle: ->
    @writeScript res while res = @sq()
    cb(@hash) while cb = @hq()
    return

  bundle: do ->
    basePath = path.resolve(__dirname, '../../')

    listScripts = (cb) ->
      clientFiles basePath, (err, paths) ->
        if err?
          console.error "Error listing client files at #{basePath}"
          paths = []

        paths = paths.map (p) -> path.resolve(basePath,p)
        paths.push path.resolve(basePath,"ace")
        cb(paths)

      return

    readExterns = (cb) ->
      clientExterns basePath, (err, paths) ->
        if err?
          console.error "Error listing client externs files at #{basePath}"
          return cb('')

        async.map paths, fs.readFile, (err, contents) ->
          if err?
            console.error "Error reading client externs at #{basePath}"
            return cb('')
          cb contents.map((content) -> content.toString('utf-8')).join('\n')

        return
      return

    bundleScripts = (debug, cb) ->
      listScripts (files) ->
        script = browserify(files)
          .transform(coffeeify)
          .bundle({debug: debug})

        script = script.pipe uglifier unless debug

        result = []
        script.on 'data', (data) -> result.push data.toString('utf-8')
        script.on 'end', ->
          readExterns (content) ->
            result.push content
            cb(result.join(''))
        return

    ->
      return if @bundling
      @bundling = true
      bundleScripts @debug, (@script) =>
        @hash = hash(script)
        @bundling = false
        @didBundle()


module.exports = Bundler
