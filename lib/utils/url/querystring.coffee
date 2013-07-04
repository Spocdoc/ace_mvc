# derived partly from node

sep = '&'
eq = '='
rPlus = /\+/g

module.exports = {}

module.exports.parseValue = parseValue = decodeURIComponent

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

module.exports.stringifyValue = prim = (v) ->
  switch typeof v
    when 'string' then encodeURI(v)
    when 'boolean'
      if v then 'true' else 'false'
    when 'number'
      if isFinite(v) then v else ''
    else ''

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

    ((if Array.isArray(v) then strA(k,v) else str(k,v)) for k,v of obj).join(sep)





