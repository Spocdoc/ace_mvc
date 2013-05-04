_ = module.exports = {}

_.defaults = (obj, others...) ->
  for other in others
    obj[k] = v for k,v of other when obj[k] is undefined
  obj

