{extend} = require '../../mixin'

global.$ = require 'cheerio'

extend global.$('').constructor.prototype,

  parents: ->
    e = this
    e = e.parent() while e[0].parent && e[0].parent.type isnt 'root'

  on: ->

