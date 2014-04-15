joinerOps =
  '$and': 1
  '$or': 1
  '$nor': 1

parsePart = (field, spec, parent) ->
  if field is '$text'
    return false unless spec
    parent[field] =
      '$search': spec
    return true

  return true unless typeof spec is 'object' and spec

  keptKeys = 0

  for k,v of spec
    keep = true

    switch k
      when '$mod' then keep = v[0]? and v[1]?
      # when '$regex' then
      when '$all' then keep = v?.length
      when '$allc'
        keep = false
        if v?.length
          arr = []
          elems = []
          for elem in v
            if elem.length > 1
              (obj = {})[field] = '$in': elem
              arr.push obj
            else
              elems.push elem[0]
          if arr.length
            if pa = parent['$and']
              pa.push arr...
            else
              parent['$and'] = arr
          if elems.length
            ++keptKeys
            if pa = spec['$all']
              pa.push elems...
            else
              spec['$all'] = elems
      when '$gt' then keep = v?
      when '$gte' then keep = v?
      when '$lt' then keep = v?
      when '$lte' then keep = v?
      # when '$ne' then
      # when '$in'
      # when '$nin'
      when '$elemMatch'
        if keep = v?
          keep = 0
          for k1,v1 of v
            if parsePart k1, v1
              ++keep
            else
              delete v[k1]
      when '$size' then keep = v?
      when '$not' then keep = parsePart k, v

    if keep
      ++keptKeys
    else
      delete spec[k]

  keptKeys

parseClause = (spec) ->
  keptKeys = 0

  for k,v of spec
    if joinerOps[k]
      v2 = []; i = 0
      if v
        for clause in v
          v2[i++] = clause if parseClause clause
      if i
        ++keptKeys
        spec[k] = v2
      else
        delete spec[k]
    else
      if parsePart k,v, spec
        ++keptKeys
      else
        delete spec[k]

  keptKeys

# mongodb for "invalid" queries returns no results. invalid includes queries with empty text searches or empty $all conditions
module.exports = (spec) ->
  parseClause spec
  spec

