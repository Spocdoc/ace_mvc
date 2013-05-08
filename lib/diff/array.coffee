# NOTE: some of this is written in a strange way (use of quotes) to accommodate the (terrible) design decisions of Google's Closure compiler

require '../polyfill'

makeValueMap = (hash, arr) ->
  ret = []
  (ret[v] ||= []).push arr[i] for v,i in hash
  ret

makeHashArr = (hash, arr) ->
  hash(v) for v in arr


# returns an array of move, insert and delete operations to transform `from` to `to`
# linear time without move. worst case quadratic time with move
module['exports']['diff'] = (from, to, options = {}) ->
  result = []

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
      else if options['deep'] and lastSpec?['o'] == -op and lastSpec['i'] == index
        result.pop()
        spec['o'] = 0
        spec['d'] = options['deep']((if op > 0 then lastValue else value), (if op > 0 then value else lastValue), options)
      else
        spec['v'] = value if op > 0

      index = -1 + result.push spec

      unless ref
        lastSeen[hash] = index
        lastSpec = spec
        lastValue = value

      return

  toHash = makeHashArr hash, to
  toMap = makeValueMap toHash, to

  fromHash = makeHashArr hash, from
  fromMap = makeValueMap fromHash, from

  fromCount = from.length
  toCount = to.length

  laterToIndex = laterFromIndex = fromIndex = toIndex = 0

  while fromIndex < fromCount && toIndex < toCount
    fh = fromHash[fromIndex]
    th = toHash[toIndex]

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
    addOp(-1,fromHash[fromIndex],from[fromIndex],toIndex)
    ++fromIndex

  while toIndex < toCount
    addOp(1,toHash[toIndex],to[toIndex],toIndex)
    ++toIndex

  return result

# takes the result of diff and returns a transformed array (also linear time)
module['exports']['apply'] = (arr, ops, options = {}) ->
  srcIndex = 0
  dstIndex = 0

  res = []
  saved = []

  options['deep'] ||= (a,diff) -> diff

  for o,k in ops
    `var i, j, index=o['i'];
    for (i = 0, j = index - dstIndex; i < j; ++i)
      res.push(arr[srcIndex++]);
    dstIndex = index;`

    if o['o']
      switch o['o']
        when -1
          if o['r']?
            saved[o['r']] = arr[srcIndex]
          else if o['p']?
            res[o['p']] = arr[srcIndex]
          ++srcIndex
        when 1
          v = o['v']
          res.push v ?= saved[k]
          ++dstIndex
    else if o['d']?
      res.push options['deep']?(arr[srcIndex], o['d'], options)
      ++srcIndex
      ++dstIndex

  `for (var j = arr.length; srcIndex < j; ++srcIndex)
    res.push(arr[srcIndex]);`

  return res

