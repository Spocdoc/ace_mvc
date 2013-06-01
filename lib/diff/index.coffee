`// ==ClosureCompiler==
// @compilation_level ADVANCED_OPTIMIZATIONS
// @js_externs module.exports, a.find, a.add
// @formatting pretty_print
// ==/ClosureCompiler==
`
Registry = require '../registry'
{'diff': diffString, 'patch': patchString} = require('./string')
clone = require '../clone'

types = ['string','number','object']
registry = new Registry

diffNumber = (from, to, options) ->
  return false if to == from
  to

patchNumber = (obj, diff, options) ->
  return diff if typeof diff is 'number'
  switch diff[0]
    when 'd' then obj += +diff.substr(1)
    when 'a' then obj &= +diff.substr(1)
    when 'o' then obj |= +diff.substr(1)

diff = (from, to, options = {}, key) ->
  if typeof from isnt typeof to
    spec = {}
    if key?
      spec['k'] = key
      res = spec
    else
      res = [spec]

    if typeof to in types
      spec['o'] = 1
      spec['v'] = clone to
    else
      spec['o'] = -1

    return res

  # handle immutable objects separately
  switch typeof from
    when 'number'
      d = diffNumber(from, to, options)
    when 'string'
      d = diffString(from, to, options)
    else
      return false unless r = registry.find from
      d = r.diff from, to, options

  if d == false
    false
  else if key?
    { 'o': 0, 'k': key, 'd': d }
  else
    d

patch = (obj, ops, options) ->
  # handle immutable objects separately
  switch typeof obj
    when 'number'
      patchNumber(obj, ops, options)
    when 'string'
      patchString(obj, ops, options)
    else
      return false unless r = registry.find obj
      r.patch obj, ops, options

register = (constructor, diff, patch) ->
  registry.add constructor,
    diff: diff
    patch: patch
  return

stub = (path, to, index=0) ->
  return clone to unless (p=path[index])?
  obj = if typeof p is 'number' then [] else {}
  obj[p] = stub(path, to, ++index)
  obj

module.exports = exports = (from, to, options = {}) ->
  options['deep'] = diff
  options['move'] ?= true

  if options['path']
    # to represents only part of the from object.
    for p,i in options['path']
      if !from[p]?
        return false if from[p] is (v = stub(options['path'][(i+1)..],to))
        return [{'o': 1, 'k': options['path'][0..i].join('.'), 'v': v}]
      else
        from = from[p]

    if result = diff from, to, options, options['path'].join('.')
      return [result]
    else
      return false

  diff(from, to, options)

exports['patch'] = (obj, ops, options = {}) ->
  options['deep'] = patch
  patch(obj, ops, options)

exports['register'] = register

## Register standard types

{'diff': diffArr, 'patch': patchArr} = require('./array')
{'diff': diffObj, 'patch': patchObj} = require('./object')

register Object, diffObj, patchObj

register Array,
  ((from, to, options) ->
    res = diffArr(from,to,options)
    return false unless res.length
    res),
  ((obj, diff, options) ->
    res = patchArr(obj, diff, options)
    obj.splice(0)
    obj[k] = v for v,k in res
    obj)

register Date,
  ((from, to, options) ->
    fromTime = from.getTime()
    toTime = to.getTime()
    return false if fromTime == toTime
    toTime - fromTime),
  ((obj, diff, options) ->
    obj.setTime(obj.getTime() + diff)
    obj)
