Template = require '../../mvc/template'
View = require '../../mvc/view'
Controller = require '../../mvc/controller'

fs = require 'fs'
path = require 'path'

templateLoaders =
  'jade': (str) -> require('jade').compile(str)()
  'html': (str) -> str
  'htm': (str) -> str

loadFiles = (arr, templates, root, type) ->
  for file in fs.readdirSync root
    fullPath = "#{root}/#{file}"
    stat = fs.statSync(fullPath)

    if stat.isDirectory()
      switch file
        when 'views'
          loadFiles arr, templates, fullPath, View
        when 'controllers'
          loadFiles arr, templates, fullPath, Controller
        when 'templates', '+'
          loadFiles arr, templates, fullPath
        else
          arr.push file
          loadFiles arr, templates, fullPath, type
          arr.pop()

      continue

    extname = path.extname(file)
    base = path.basename(file, extname)
    ext = extname[1..]
    name = arr.join('/')

    continue unless base[0] isnt '.'

    switch type
      when View, Controller
        unless base is 'index'
          name += '/' if name
          name += "#{base}"
        type.add name, require fullPath

      else
        if ext in templates
          unless base is 'template'
            name += '/' if name
            name += "#{base}"
          Template.add name, templateLoaders[ext](fs.readFileSync(fullPath,'utf-8'))

        else if base is 'view'
          View.add name, require fullPath
        else if base is 'controller'
          Controller.add name, require fullPath
        else
          throw new Error("Unrecognized file type while loading mvc: #{fullPath}")

module.exports = (settings) ->
  loadFiles [], settings.templates, settings.files
  return

