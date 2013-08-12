quote = require '../quote'

stringify = (obj) ->
  return quote obj unless obj and typeof obj is 'object'

  str = "{"
  for k,i in Object.keys(obj).sort()
    v = obj[k]
    str += "#{if i > 0 then ',' else ''}#{quote(k)}:#{stringify(v)}"
  str + "}"


module['exports'] = (obj, full) ->
  switch typeof obj
    when 'number' then return obj
    when 'string' then return obj if obj.length <= 40

  str = stringify obj
