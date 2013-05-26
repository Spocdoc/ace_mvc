Registry = require '../registry'

registry = new Registry

copyKeys = (obj) ->
  dst = new obj.constructor
  dst[k] = clone(v) for k,v of obj
  dst

clone = (obj) ->
  return obj if typeof obj isnt 'object' or obj == null
  return r.clone(obj) if r = registry.find obj
  new obj.constructor(obj)

clone.register = register = (constructor, fn) ->
  registry.add constructor,
    clone: fn
  return

module.exports = clone

## Register standard types

register Object, copyKeys
register Array, copyKeys
