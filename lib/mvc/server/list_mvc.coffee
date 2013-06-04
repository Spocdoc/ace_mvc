fs = require 'fs'
path = require 'path'
templateLoader = require './template_loader'
styleLoader = require './style_loader'
async = require 'async'
debug = global.debug 'ace:boot:mvc'

getInode = async.memoize (filePath, cb) ->
  fs.stat filePath, (err, stat) ->
    return cb(err) if err?
    cb null, ""+stat.ino

formType = (type, base, stub) ->
  unless base is stub
    type += '/' if type
    type += "#{base}"
  type

formStyleType = (type, base, stub) ->
  unless base is stub
    type += '/' if type
    type += "#{base}"
  type

listMvc = (mvc, arr, root, pending, done, className) ->
  for file in fs.readdirSync root
    fullPath = "#{root}/#{file}"
    stat = fs.statSync(fullPath)

    if stat.isDirectory()
      switch file
        when 'views'
          listMvc mvc, arr, fullPath, pending, done, 'view'
        when 'controllers'
          listMvc mvc, arr, fullPath, pending, done, 'controller'
        when 'styles','templates', '+'
          listMvc mvc, arr, fullPath, pending, done
        else
          arr.push file
          listMvc mvc, arr, fullPath, pending, done, className
          arr.pop()

      continue

    extname = path.extname(file)
    base = path.basename(file, extname)
    ext = extname[1..]
    type = arr.join('/')
    reqPath = "#{root}/#{base}"

    continue unless base[0] isnt '.'

    if templateLoader.handles ext
      type = formType type, base, 'template'
      debug "loaded template   #{type}"

      pending()
      do (fullPath, type) ->
        async.waterfall [
          (next) -> fs.readFile fullPath, 'utf-8', next
          (content, next) -> templateLoader.compile fullPath, type, content, next
          (parsed, next) ->
            mvc['template'][type] = parsed
            next()
        ], done

    else if styleLoader.handles ext
      type = formStyleType type, base, 'style'
      debug "loaded style      #{type}"

      pending()
      do (fullPath, type) ->
        async.waterfall [
          (next) -> fs.readFile fullPath, 'utf-8', next
          (content, next) -> styleLoader.compile fullPath, type, content, next
          (parsed, next) ->
            mvc['style'][type] = parsed
            next()
        ], done

    else if className in ['view','controller']
      type = formType type, base, 'index'
      debug "loaded #{if className is 'view' then "view      " else "controller"} #{type}"
      mvc[className][type] = reqPath

    else if base is 'view'
      debug "loaded view       #{type}"
      mvc['view'][type] = reqPath

    else if base is 'controller'
      debug "loaded controller #{type}"
      mvc['controller'][type] = reqPath

module.exports = do ->
  cache = {}

  (root, cb) ->
    root = path.resolve root

    getInode root, (err, inode) ->
      return cb(err) if err?
      return cb(null, c) if c = cache[inode]

      mvc =
        template: {}
        view: {}
        controller: {}
        style: {}

      count = 0
      done = (err) ->
        return cb(err) if err?
        unless --count
          cb null, cache[inode] = mvc
      pending = -> ++count

      pending()
      listMvc mvc, [], root, pending, done
      done()

