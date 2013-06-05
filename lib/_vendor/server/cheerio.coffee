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

  css: (prop, value) ->
    if undefined isnt style = @attr 'style'
      existing = style.split(/;\s*/)
    else
      existing = []

    found = existing.length

    for name,i in existing
      if name.substr(0,name.indexOf(':')) is prop
        found = i
        break

    existing[found] = "#{prop}: #{value}"
    @attr 'style', existing.join("; ")


