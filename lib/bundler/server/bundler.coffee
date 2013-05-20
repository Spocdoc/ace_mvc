browserify = require 'browserify'
coffeeify = require 'coffeeify'
fs = require 'fs'
stream = require 'stream'
uglifier = new (require('browserify-uglify'))
path = require 'path'
queue = require '../../queue'
async = require 'async'
listMvc = require '../../mvc/server/list_mvc'
{defaults} = require '../../mixin'
temp = require '../../temp'

hash = (str) ->
   require('crypto').createHash('sha1').update(str).digest("hex")

quote = do ->
  regex = /(['\\])/g
  (str) ->
    '\''+str.replace(regex,'\\$1')+'\''

directories = (basePath, cb) ->
  async.waterfall [
    (next) -> fs.readdir basePath, (err, files) -> next(err,files)
    (files, next) ->
      async.mapSeries files.map((file) -> "#{basePath}/#{file}"), fs.stat, (err, stats) ->
        return next err if err?
        dirs = []
        for stat,i in stats when stat.isDirectory()
          dirs.push files[i]
        next(err, dirs)
  ], cb
  return

listClientFiles = (basePath, filter, cb) ->
  async.waterfall [
    (next) -> directories basePath, (err,dirs) -> next err, dirs.filter filter
    (dirs, next) -> async.filter dirs, ((a, b) -> fs.exists("#{basePath}/#{a}/client",b)), (cl) -> next(null, cl)
    (dirs, next) ->
      dirs.sort()
      next null, (dirs.map (a) -> "#{a}/client")
  ], (err, dirs) ->
    if err?
      console.error "Error listing client files at #{basePath}",err
      cb([])
    else
      cb(dirs)

readClientFiles = (basePath, filter, cb) ->
  async.waterfall [
    (next) -> listClientFiles basePath, filter, (dirs) -> next(null, dirs)
    (dirs, next) ->
      async.mapSeries dirs.map((dir) -> "#{basePath}/#{dir}"), fs.readdir, (err, fileses) ->
        return next err if err?
        paths = []
        for files,i in fileses
          for file in files
            paths.push "#{basePath}/#{dirs[i]}/#{file}"
        next(err, paths)
    (paths, next) ->
      async.map paths, fs.readFile, (err, contents) ->
        return next err if err?
        next err, contents.map((content) -> content.toString('utf-8')).join('\n')
  ], (err, content) ->
    if err?
      console.error "Error reading client files at #{basePath}",err
      cb('')
    else
      cb(content)

class Bundler
  constructor: (@settings) ->
    @sq = queue() # script queue
    @hq = queue() # hash queue
    @bundle()

  getHash: (cb) ->
    if @hash?
      cb @hash
    else
      @hq cb
    return

  writeScript: (stream) ->
    if @script?
      if (type = stream.scriptType)?
        stream.end @script[type]
      else
        stream.end @script.prod
    else
      @sq(stream)
    return

  didBundle: ->
    @writeScript res while res = @sq()
    @getHash cb while cb = @hq()
    return

  bundle: do ->
    basePath = path.resolve(__dirname, '../../')

    listScripts = (cb) ->
      listClientFiles basePath, ((p) -> p[0] isnt '_'), (paths) ->
        paths = paths.map (p) -> path.resolve(basePath,p)
        cb(paths)
        return
      return

    readExterns = (cb) ->
      readClientFiles basePath, ((p) -> p[0] is '_'), (content) ->
        cb(content)
        return
      return

    makeLoadFile = (settings, cb) ->
      mvc = listMvc(settings['mvc']['templates'], settings['mvc']['files'])
      entry = settings['globals']

      async.waterfall [
        (next) -> listScripts (files) -> next(null, files)
        (files, next) -> temp.open prefix: 'load-', suffix: '.coffee', dir: __dirname, (err, file) -> next(err,file,files)
        (file, files, next) ->
          script = []

          for p in files
            p = path.relative(__dirname, p)
            script.push "require #{quote(p)}"

          for type in ['template','view','controller']
            clazz = type[0].toUpperCase() + type[1..]
            p = path.relative(__dirname, path.resolve(basePath, "./mvc/#{type}"))
            script.push "#{clazz} = require #{quote(p)}"

          # global entry points
          for n,p of entry
            p = path.relative(__dirname, p)
            script.push "global[#{quote(n)}] = require #{quote(p)}"

          # also require routes

          for name, dom of mvc['template']
            script.push """
            Template.add #{quote(name)}, \'\'#{quote(dom)}\'\'
            """

          for type in ['view','controller']
            for name, p of mvc[type]
              p = path.relative(__dirname, p)
              clazz = type[0].toUpperCase() + type[1..]
              script.push "#{clazz}.add #{quote(name)}, require #{quote(p)}"

          fs.write file.fd, script.join('\n')
          fs.close file.fd, (err) -> next(err, file.path)
      ], (err, file) ->
        console.error "Error writing load file" if err?
        cb(file)
        return
      return

    bundle = (debug, file, cb) ->
      script = browserify(file)
        .transform(coffeeify)
        .bundle({'debug': debug})

      script = script.pipe uglifier unless debug

      result = []
      script.on 'data', (data) -> result.push data.toString('utf-8')
      script.on 'end', -> cb result.join('')
      return

    bundleScripts = (file, cb) ->
      async.parallel
        local: (reply) -> bundle true, file, (res) -> reply(null,res)
        prod: (reply) -> bundle false, file, (res) -> reply(null,res)
        extern: (reply) -> readExterns (res) -> reply(null,res)
        (err, obj) ->
          if err?
            console.error "Error creating bundle: #{err}"
            cb()
          else
            obj.prod = obj.extern + obj.prod
            cb(obj)
      return

    ->
      return if @bundling
      @bundling = true
      makeLoadFile @settings, (file) =>
        bundleScripts file, (@script) =>
          # TODO: unless @script, set a timeout and try to bundle again later
          @hash = {}
          @hash[k] = hash(@script[k]) for k,script of @script
          @bundling = false
          @didBundle()


module.exports = Bundler
