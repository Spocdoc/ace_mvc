module.exports.extend = (obj, mixin) ->
  obj[name] = method for name, method of mixin
  obj
module.exports.include = (klass..., mixin) ->
  module.exports.extend inst.prototype, mixin for inst in klass
