fs = require 'fs'
path = require 'path'
templateLoader = require './template_loader'
styleLoader = require './style_loader'
async = require 'async'
debug = global.debug 'ace:boot:mvc'

validateName = do ->
  regex = /^[a-zA-Z]+[_a-zA-Z0-9\/]*$/
  (name) ->
    unless !!regex.exec(name)
      throw new Error("Invalid mvc component name: #{name}")
    return

getInode = async.memoize (filePath, cb) ->
  fs.stat filePath, (err, stat) ->
    return cb(err) if err?
    cb null, ""+stat.ino

formName = (name, base, stub) ->
  unless base is stub
    name += '/' if name
    name += "#{base}"
  validateName name
  name

formStyleName = (name, base, stub) ->
  unless base is stub
    name += '/' if name
    name += "#{base}"
  validateName name if name # allow blank style names for the default style
  name

listMvc = (mvc, arr, root, pending, done, type) ->
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
          listMvc mvc, arr, fullPath, pending, done, type
          arr.pop()

      continue

    extname = path.extname(file)
    base = path.basename(file, extname)
    ext = extname[1..]
    name = arr.join('/')
    reqPath = "#{root}/#{base}"

    continue unless base[0] isnt '.'

    if templateLoader.handles ext
      name = formName name, base, 'template'
      debug "loaded template   #{name}"

      pending()
      do (fullPath, name) ->
        async.waterfall [
          (next) -> fs.readFile fullPath, 'utf-8', next
          (content, next) -> templateLoader.compile fullPath, name, content, next
          (parsed, next) ->
            mvc['template'][name] = parsed
            next()
        ], done

    else if styleLoader.handles ext
      name = formStyleName name, base, 'style'
      debug "loaded style      #{name}"

      pending()
      do (fullPath, name) ->
        async.waterfall [
          (next) -> fs.readFile fullPath, 'utf-8', next
          (content, next) -> styleLoader.compile fullPath, name, content, next
          (parsed, next) ->
            mvc['style'][name] = parsed
            next()
        ], done

    else if type in ['view','controller']
      name = formName name, base, 'index'
      debug "loaded #{if type is 'view' then "view      " else "controller"} #{name}"
      mvc[type][name] = reqPath

    else if base is 'view'
      debug "loaded view       #{name}"
      mvc['view'][name] = reqPath

    else if base is 'controller'
      debug "loaded controller #{name}"
      mvc['controller'][name] = reqPath

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

