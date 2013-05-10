module['exports'] =
  'diff': (from, to, options) ->
    res = []

    deep = options['deep'] || (a,b) ->
      if a == b then false else b

    for k,v of from
      if (spec = deep(v, to[k], options, k)) != false
        res.push spec
    
    for k,v of to when !from[k]?
      res.push {'o': 1, 'k': k, 'v': v}

    return if res.length then res else false

  'patch': (obj, ops, options) ->
    deep = options['deep'] || (a,diff) -> diff

    for op in ops
      switch op['o']
        when -1
          delete obj[op['k']]
        when 1
          obj[op['k']] = op['v']
        else
          obj[op['k']] = deep(obj[op['k']], op['d'], options)
    obj


