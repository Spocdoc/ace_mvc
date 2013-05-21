fs = require 'fs'
path = require 'path'

templateLoaders =
  'html': (str) -> str
  'htm': (str) -> str

listMvc = (result, arr, templates, root, type) ->
  for file in fs.readdirSync root
    fullPath = "#{root}/#{file}"
    stat = fs.statSync(fullPath)

    if stat.isDirectory()
      switch file
        when 'views'
          listMvc result, arr, templates, fullPath, 'view'
        when 'controllers'
          listMvc result, arr, templates, fullPath, 'controller'
        when 'templates', '+'
          listMvc result, arr, templates, fullPath
        else
          arr.push file
          listMvc result, arr, templates, fullPath, type
          arr.pop()

      continue

    extname = path.extname(file)
    base = path.basename(file, extname)
    ext = extname[1..]
    name = arr.join('/')
    reqPath = "#{root}/#{base}"

    continue unless base[0] isnt '.'

    if ext in templates
      unless base is 'template'
        name += '/' if name
        name += "#{base}"
      result['template'][name] = templateLoaders[ext](fs.readFileSync(fullPath,'utf-8'))

    else if type in ['view','controller']
      unless base is 'index'
        name += '/' if name
        name += "#{base}"
      result[type][name] = reqPath

    else if base is 'view'
      result['view'][name] = reqPath

    else if base is 'controller'
      result['controller'][name] = reqPath

module.exports = (templates, root) ->
  for type in templates when !templateLoaders[type]
    templateLoaders[type] = (str) -> require(type).compile(str)()

  mvc =
    template: {}
    view: {}
    controller: {}

  listMvc mvc, [], templates, root
  mvc

