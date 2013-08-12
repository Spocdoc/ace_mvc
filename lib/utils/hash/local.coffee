quote = require '../quote'

digest = global.digest || (str) ->
  hash = 5381
  `for (var i = 0; i < str.length; ++i)
      hash = ((hash << 5) + hash) + str.charCodeAt(i);`
  return hash

module['exports'] = (obj) ->
  switch typeof obj
    when 'number' then return obj
    when 'string' then return obj if obj.length <= 40

  str = JSON.stringify obj
  if str.length <= 40
    str
  else
    digest str
