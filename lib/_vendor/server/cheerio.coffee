global.$ = require 'cheerio'

extend = (obj, mixin) ->
  obj[name] = method for name, method of mixin
  obj

extend global.$('').constructor.prototype,

  parents: ->
    e = this
    e = e.parent() while e[0].parent && e[0].parent.type isnt 'root'

  on: ->
  scrollLeft: ->
  scrollTop: ->


