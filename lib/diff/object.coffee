# @returns an object representing the changed values in the diff
changes = (ops, to) ->
  res = {}
  for op in ops
    k = op['k']
    switch op['o']
      when 1
        (res[1] ||= {})[k] = to[k]
      when -1
        return {'-1': null} unless k?
        (res[-1] ||= []).push k
      else
        if typeof to[k] isnt 'object' or to[k].constructor != Object
          (res[1] ||= {})[k] = to[k]
        else
          (res[0] ||= {})[k] = changes(op['d'], to[k])
  return res

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
      if (k = op['k'])?
        switch op['o']
          when -1
            delete obj[k]
          when 1
            obj[k] = op['v']
          else
            obj[k] = deep(obj[k], op['d'], options)
      else
        switch op['o']
          when -1
            return undefined
          when 1
            return op['v']
          else
            return deep(obj, op['d'], options)
    obj

  'changes': changes

