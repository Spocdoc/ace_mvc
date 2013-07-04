registry = new (require '../registry')
clone = require '../clone'

stub = (path, to, index=0) ->
  return clone to unless (p=path[index])?
  obj = if typeof p is 'number' then [] else {}
  obj[p] = stub(path, to, ++index)
  obj

diff = (from, to, options = {}, key) ->
  return false if from is to

  # cumbersome because typeof null is "object"
  if typeof from isnt typeof to or from is null or to is null
    spec = {}
    if key?
      spec['k'] = key
      res = spec
    else
      res = [spec]

    if typeof to in ['string','number','object']
      spec['o'] = 1
      spec['v'] = clone to
    else
      spec['o'] = -1

    return res

  # handle immutable objects separately
  return false unless r = registry.find from
  d = r.diff from, to, options

  if d == false
    false
  else if key?
    { 'o': 0, 'k': key, 'd': d }
  else
    d

patch = (obj, ops, options) ->
  return false unless r = registry.find obj
  r.patch obj, ops, options

module.exports = ret = (from, to, options = {}) ->
  options['deep'] = diff
  options['move'] ?= true

  if options['path']
    # to represents only part of the from object.
    for p,i in options['path']
      if !from[p]?
        return false if from[p] is (v = stub(options['path'][(i+1)..],to))
        return [{'o': 1, 'k': options['path'][0..i].join('.'), 'v': clone v}]
      else
        from = from[p]

    if result = diff from, to, options, options['path'].join('.')
      return [result]
    else
      return false

  diff(from, to, options)

ret['register'] = (constructor, diff, patch) ->
  unless patch
    registry.add constructor, diff
  else
    registry.add constructor,
      diff: diff
      patch: patch

  return

ret['patch'] = (obj, ops, options = {}) ->
  options['deep'] = patch
  patch(obj, ops, options)

# Register standard types
require('./register')(ret)

ret['toMongo'] = require './to_mongo'
ret['toOutlets'] = require './to_outlets'
