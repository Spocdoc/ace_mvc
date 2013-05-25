glob = require 'glob'
path = require 'path'
lib = path.resolve __dirname, '../../'
async = require 'async'
closurify = require 'closurify'

quote = do ->
  regexQuotes = /(['\\])/g
  regexNewlines = /([\n])/g
  (str) ->
    '\''+str.replace(regexQuotes,'\\$1').replace(regexNewlines,'\\n')+'\''

module.exports = makeLoader = (mvc, globals, options, cb) ->
  if typeof options is 'function'
    [cb,options] = [options, {}]

  async.waterfall [
    (next) -> glob './!(_*)/client', cwd: lib, nonegate: true, next

    (dirs, next) ->
      dirs.sort()

      script = []
      script.push("require(#{quote(path.resolve(lib,p))});") for p in dirs

      # global entry points
      for n,p of globals
        script.push "global[#{quote(n)}] = require(#{quote(p)});"

      # local template, view, controller
      for type in ['template','view','controller']
        clazz = type[0].toUpperCase() + type[1..]
        p = path.resolve(lib, "./mvc/#{type}")
        script.push "var #{clazz} = require(#{quote(p)});"

      # build templates
      for name, dom of mvc['template']
        script.push "Template.add(#{quote(name)}, #{quote(dom)});"

      # build views & controllers
      for type in ['view','controller']
        keys = Object.keys mvc[type]
        keys.sort()
        for name,i in keys
          clazz = type[0].toUpperCase() + type[1..]
          reqName = "#{type[0]}#{i}" # e,g, "v1", "v2", "c1", ...
          # the require(path,1) is a hack so it doesn't get replaced in closurify
          script.push "#{clazz}.add(#{quote(name)}, require(#{quote(reqName)},1));"

      closurify script.join('\n'), options, cb

  ]
