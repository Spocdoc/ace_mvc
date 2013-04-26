module.exports.extend = (obj..., mixin) ->
  for o in obj
    o[name] = method for name, method of mixin
  return
module.exports.include = (klass..., mixin) ->
  module.exports.extend inst.prototype, mixin for inst in klass
  return
