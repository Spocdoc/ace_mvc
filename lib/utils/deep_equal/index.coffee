module.exports = deepEqual = (a, b) ->
  return false if typeof a isnt typeof b
  return b is a if typeof a isnt 'object' or a is null
  for k,v of a
    return false unless deepEqual b[k], v
  for k,v of b
    return false unless deepEqual a[k], v
  true
