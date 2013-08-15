# derived partly from node
OJSON = require '../ojson'

sep = '&'
eq = '='
rPlus = /\+/g
regexAmp=/&/g
regexHash=/#/g

module.exports = {}

module.exports.stringifyValue = stringValue = (v) ->
  encodeURI(OJSON.stringify v).replace(regexAmp,'%26').replace(regexHash,'%23')

module.exports.parseValue = parseValue = (v) ->
  if v
    try
      OJSON.parse decodeURIComponent(v)
    catch _error
      undefined
  else
    undefined

module.exports.stringifyKey = stringKey = (k) ->
  encodeURI(''+k).replace(regexAmp,'%26').replace(regexHash,'%23')

module.exports.parseKey = parseKey = (k) -> k and decodeURIComponent(k)

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
      k = parseKey(kstr)
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
    "#{stringKey(k)}#{eq}#{stringValue(v)}"

  strA = (name, arr) ->
    ks = "#{stringKey(name)}#{eq}"
    ("#{ks}#{stringValue(v)}" for v in arr).join(sep)

  (obj, name='') ->
    return '' unless obj?
    return str(name, obj) if typeof obj isnt 'object'
    return strA(name, obj) if Array.isArray(obj)

    ((if Array.isArray(v) and v.length < 3 then strA(k,v) else str(k,v)) for k,v of obj).join(sep)





