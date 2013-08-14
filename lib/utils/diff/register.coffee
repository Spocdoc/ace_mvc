module.exports = (ret) ->
  register = ret['register']

  arrayDiff = require('./types/array')

  newArrayDiff = (from, to, options) ->
    res = arrayDiff(from,to,options)
    return false unless res.length
    res

  newArrayDiff.patch = newArrayDiff['patch'] = (obj, diff, options) ->
    res = arrayDiff.patch(obj, diff, options)
    obj[k] = v for v,k in res
    obj.length = k
    obj

  register Array, newArrayDiff
  register Object, require('./types/object')
  register Number, require('./types/number')
  register String, require('./types/string')
  register Date, require('./types/date')

  return
