extend = (obj..., mixin) ->
  for o in obj
    o[name] = method for name, method of mixin
  return

include = (class_..., mixin) ->
  extend inst.prototype, mixin for inst in class_
  return

defaults = (obj, others...) ->
  for other in others
    obj[k] = v for k,v of other when obj[k] is undefined
  obj

module.exports =
  extend: extend
  include: include
  defaults: defaults
