module.exports = (ret) ->
  register = ret['register']

  {diff, patch} = require('./types/array')

  diffArray = (from, to, options) ->
    res = diff(from,to,options)
    return false unless res.length
    res

  patchArray = (obj, diff, options) ->
    res = patch(obj, diff, options)
    obj.splice(0)
    obj[k] = v for v,k in res
    obj

  register Array, diffArray, patchArray
  register Object, require('./types/object')
  register Number, require('./types/number')
  register String, require('./types/string')
  register Date, require('./types/date')

  ret['arrays'] =
    'diff': (from, to) -> diffArray from, to, 'move': true
    'patch': patchArray

  return
