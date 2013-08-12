# derived partly from node
OJSON = require '../ojson'

sep = '&'
eq = '='
rPlus = /\+/g
regexAmp=/&/g
regexHash=/#/g

module.exports = {}

module.exports.stringifyValue = prim = (v) ->
  encodeURI(OJSON.stringify v).replace(regexAmp,'%26').replace(regexHash,'%23')

module.exports.parseValue = parseValue = (v) ->
  if v
    try
      OJSON.parse decodeURIComponent(v)
    catch _error
      undefined
  else
    undefined

module.exports.parse = (qs) ->
  obj = {}

  return obj if typeof qs isnt "string" or qs.length is 0

  for x in qs.replace(rPlus, '%20').split(sep)
    idx = x.indexOf(eq)
    if idx >= 0
      kstr = x.substr(0, idx)
      vstr = x.substr(idx + 1)
    else
      kstr = x
      vstr = ""

    try
      k = parseValue(kstr)
      v = parseValue(vstr)
    catch e
      return {}

    if not obj.hasOwnProperty k
      obj[k] = v
    else if Array.isArray(obj[k])
      obj[k].push v
    else
      obj[k] = [obj[k], v]

  obj

module.exports.stringify = do ->

  str = (k,v) ->
    return '' unless k
    "#{prim(k)}#{eq}#{prim(v)}"

  strA = (name, arr) ->
    return '' unless name
    ks = "#{prim(name)}#{eq}"
    ("#{ks}#{prim(v)}" for v in arr).join(sep)

  (obj, name='') ->
    return '' unless obj?
    return str(name, obj) if typeof obj isnt 'object'
    return strA(name, obj) if Array.isArray(obj)

    ((if Array.isArray(v) and v.length < 3 then strA(k,v) else str(k,v)) for k,v of obj).join(sep)





