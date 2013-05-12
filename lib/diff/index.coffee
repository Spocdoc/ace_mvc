{'diff': diffString, 'patch': patchString} = require('./string')

types = ['string','number','object']
registry = {}

diffNumber = (from, to, options) ->
  return false if to == from
  to

patchNumber = (obj, diff, options) ->
  return diff if typeof diff is 'number'
  switch diff[0]
    when 'd' then obj += +diff.substr(1)
    when 'a' then obj &= +diff.substr(1)
    when 'o' then obj |= +diff.substr(1)

findInRegistry = (obj) ->
  return false unless reg = registry[obj.constructor.name]
  (return r if obj instanceof r.type) for r in reg
  false

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
      spec['v'] = to
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
      return false unless r = findInRegistry from
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
      return false unless r = findInRegistry obj
      r.patch obj, ops, options

register = (constructor, diff, patch) ->
  if typeof constructor is 'object'
    (registry[constructor.type.name] ||= []).push constructor
  else
    (registry[constructor.name] ||= []).push
      'type': constructor
      'diff': diff
      'patch': patch
  return

module['exports'] = exports = (from, to, options = {}) ->
  options['deep'] = diff
  options['move'] ?= true
  diff(from, to, options)

exports['patch'] = (obj, ops, options = {}) ->
  options['deep'] = patch
  patch(obj, ops, options)

exports['register'] = register

{'diff': diffArr, 'patch': patchArr} = require('./array')
{'diff': diffObj, 'patch': patchObj} = require('./object')

register Object, diffObj, patchObj

register
  'type': Array
  'diff': (from, to, options) ->
    res = diffArr(from,to,options)
    return false unless res.length
    res
  'patch': (obj, diff, options) ->
    res = patchArr(obj, diff, options)
    obj.splice(0)
    obj[k] = v for v,k in res
    obj

register
  'type': Date
  'diff': (from, to, options) ->
    fromTime = from.getTime()
    toTime = to.getTime()
    return false if fromTime == toTime
    toTime - fromTime
  'patch': (obj, diff, options) ->
    obj.setTime(obj.getTime() + diff)
    obj
