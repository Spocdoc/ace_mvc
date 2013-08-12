Registry = require '../registry'

registry = new Registry

module.exports = clone = (obj) ->
  return obj if typeof obj isnt 'object' or obj == null
  return r.clone(obj) if r = registry.find obj
  new obj.constructor(obj)

clone['copyKeys'] = clone.copyKeys = (obj) ->
  dst = new obj.constructor
  dst[k] = clone(v) for k,v of obj
  dst

clone.register = clone['register'] = register = (constructor, fn) ->
  registry.add constructor,
    clone: fn
  return

# Register standard types
register Object, clone.copyKeys
register Array, clone.copyKeys

