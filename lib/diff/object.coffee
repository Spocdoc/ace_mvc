`// ==ClosureCompiler==
// @compilation_level ADVANCED_OPTIMIZATIONS
// @js_externs module.exports
// ==/ClosureCompiler==
`
clone = require '../clone'

module.exports =
  'diff': (from, to, options) ->
    return false if from == to

    res = []

    deep = options['deep'] || (a,b) ->
      if a == b then false else b

    for k,v of from
      if (spec = deep(v, to[k], options, k)) != false
        res.push spec
    
    for k,v of to when !from[k]?
      res.push {'o': 1, 'k': k, 'v': clone v}

    return if res.length then res else false

  'patch': (obj, ops, options) ->
    deep = options['deep'] || (a,diff) -> diff

    for op in ops
      if (k = op['k'])?
        # k might be a compound key like foo.bar.1.baz
        o = obj
        s = k.split '.'
        `for (var j=0, je = s.length-1; j < je; ++j) o = o[s[j]];`
        k = s[je]
        switch op['o']
          when -1
            delete o[k]
          when 1
            o[k] = clone op['v']
          else
            o[k] = deep(o[k], op['d'], options)
      else
        switch op['o']
          when -1
            return undefined
          when 1
            return clone op['v']
          else
            return deep(obj, op['d'], options)
    obj

