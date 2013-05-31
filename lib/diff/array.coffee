`// ==ClosureCompiler==
// @compilation_level ADVANCED_OPTIMIZATIONS
// @js_externs module.exports
// ==/ClosureCompiler==
`
clone = require '../clone'

makeValueMap = (hashes, compare) ->
  ret = []
  (ret[v[0]] ||= []).push i for v,i in hashes
  ret

makeHashArr = (hash, arr) ->
  [hash(v),v] for v in arr

uniqueHashes = (toHash, fromHash, compare) ->
  cmp = (a,b) -> compare(a[1],b[1])

  map = {}
  (map[v[0]] || = []).push v for v in toHash
  (map[v[0]] || = []).push v for v in fromHash
  for key,arr of map
    arr[0][0] = "0:" + arr[0][0]
    arr.sort(cmp)
    `for (var i = 1, l = arr.length; i < l; ++i) {
      if (0 == cmp(arr[i-1],arr[i]))
        arr[i][0] = arr[i-1][0];
      else
        arr[i][0] = i + ":" + arr[i][0];
    }`
  return

module.exports =
  # returns an array of insert and delete operations to transform `from` to `to`
  # optionally performs diff of replaced elements and uses "move" 
  # linear time.
  # options:
  #   compare
  #   hash
  #   move
  #   replace
  #   deep
  'diff': (from, to, options = {}) ->
    result = []
    return result if from == to

    if options['replace']
      options['deep'] = (a, b) -> b

    hash = options['hash'] || (o) -> o.toString()

    addOp = do ->
      lastSeen = {}
      lastSpec = {}
      lastValue = undefined

      (op, hash, value, index) ->
        spec =
          'o': op
          'i': index

        if ref = options['move'] && (lastIndex = lastSeen[hash])? && (prev = result[lastIndex])['o'] is -op
          if op < 0
            spec['p'] = prev['i']
            delete prev['v']
          else
            prev['r'] = result.length

          delete lastSeen[hash]
        else if options['deep'] and lastSpec['o'] == -op and (op > 0 && lastSpec['i'] == index || op < 0 && lastSpec['i'] == index-1)
          spec['d'] = options['deep']((if op > 0 then lastValue else value), (if op > 0 then value else lastValue), options)

          if op < 0
            spec['p'] = lastSpec['i']
            delete lastSpec['v']
          else
            lastSpec['r'] = result.length

          delete lastSeen[hash]
          lastSpec = {}
          ref = true
        else
          spec['v'] = value if op > 0

        index = -1 + result.push spec

        unless ref
          lastSeen[hash] = index
          lastSpec = spec
          lastValue = value

        return

    toHash = makeHashArr hash, to
    fromHash = makeHashArr hash, from

    uniqueHashes toHash, fromHash, compare if compare = options['compare']

    toMap = makeValueMap toHash
    fromMap = makeValueMap fromHash

    fromCount = from.length
    toCount = to.length

    laterToIndex = laterFromIndex = fromIndex = toIndex = 0

    while fromIndex < fromCount && toIndex < toCount
      fh = fromHash[fromIndex][0]
      th = toHash[toIndex][0]

      if fh is th
        ++toIndex
        ++fromIndex
        continue

      if toMap[fh]?.some((value) -> (laterToIndex = value) >= toIndex)
        unless fromMap[th]?.some((value) -> (laterFromIndex = value) >= fromIndex) && laterToIndex - toIndex > laterFromIndex - fromIndex
          addOp(1,th,to[toIndex],toIndex)
          ++toIndex
          continue

      addOp(-1,fh,from[fromIndex],toIndex)
      ++fromIndex

    while fromIndex < fromCount
      addOp(-1,fromHash[fromIndex][0],from[fromIndex],toIndex)
      ++fromIndex

    while toIndex < toCount
      addOp(1,toHash[toIndex][0],to[toIndex],toIndex)
      ++toIndex

    # clone value assignments
    for op in result
      op['v'] = clone op['v'] if op['v']

    return result

  # takes the result of diff and returns a transformed array (also linear time)
  'patch': (arr, ops, options = {}) ->
    srcIndex = 0
    dstIndex = 0

    srcLen = arr.length

    res = []
    saved = []

    deep = options['deep'] ||= (a,diff) -> diff

    for o,r in ops
      `var i, j, index=o['i'];
      if (index == null) return void 0;
      if (index < 0) {
        index = dstIndex + (srcLen - srcIndex);
      }
      for (i = 0, j = index - dstIndex; i < j; ++i)
        res.push(arr[srcIndex++]);
      dstIndex = index;`

      # support "unless" operations -- mongodb's "addToSet" for arrays.
      # note that this breaks later index refs so is never produced by regular
      # diffs, just when converted from mongodb
      # only valid with o['i'] = -1
      if o['u']?
        continue if o['u'] in res
        o['v'] = o['u']

      switch o['o']
        when -1
          if o['r']?
            saved[o['r']] = arr[srcIndex]
          else if o['p']?
            if o['d']?
              res[o['p']] = deep(arr[srcIndex], o['d'], options)
            else
              res[o['p']] = arr[srcIndex]
          if srcIndex == srcLen
            res.pop()
            --dstIndex
          else
            ++srcIndex

        when 1
          if (v = o['v'])?
            v = clone v
          else
            v = saved[r]
          if o['d']?
            res.push deep(v, o['d'], options)
          else
            res.push v
          ++dstIndex

        else
          res.push options['deep']?(arr[srcIndex], o['d'], options)
          ++srcIndex
          ++dstIndex

    `for (var j = arr.length; srcIndex < j; ++srcIndex)
      res.push(arr[srcIndex]);`

    return res



