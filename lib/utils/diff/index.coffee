registry = new (require '../registry')
clone = require '../clone'
emptyClone = (o) -> o

stub = (path, to, index,options) ->
  return options['clone'] to unless (p=path[index])?
  obj = if typeof p is 'number' then [] else {}
  obj[p] = stub(path, to, ++index, options)
  obj

diff = (from, to, options = {}, key) ->
  return false if from is to

  # cumbersome because typeof null is "object"
  if typeof from isnt typeof to or !from? or !to?
    spec = {}
    if key?
      spec['k'] = key
      res = spec
    else
      res = [spec]

    if typeof to in ['string','number','object']
      spec['o'] = 1
      spec['v'] = options['clone'] to
    else
      spec['o'] = -1

    return res

  # handle immutable objects separately
  return false unless r = registry.find from
  d = r from, to, options

  if d == false
    false
  else if key?
    { 'o': 0, 'k': key, 'd': d }
  else
    d

patch = (obj, ops, options) ->
  return false unless r = registry.find(if obj? then obj else Object)
  r.patch obj, ops, options

module.exports = ret = (from, to, options = {}) ->
  options['deep'] = diff unless options.hasOwnProperty('deep')

  if options.hasOwnProperty('clone')
    options['clone'] ||= emptyClone
  else
    options['clone'] = clone

  if options['path']
    # to represents only part of the from object.
    for p,i in options['path']
      if !from[p]?
        return false if from[p] is (v = stub(options['path'][(i+1)..],to,0,options))
        return [{'o': 1, 'k': options['path'][0..i].join('.'), 'v': options['clone'] v}]
      else
        from = from[p]

    if result = diff from, to, options, options['path'].join('.')
      return [result]
    else
      return false

  diff(from, to, options)

ret.register = ret['register'] = (constructor, fn) -> registry.add constructor, fn

ret.patch = ret['patch'] = (obj, ops, options = {}) ->
  options['deep'] = patch

  if options.hasOwnProperty('clone')
    options['clone'] ||= emptyClone
  else
    options['clone'] = clone

  patch(obj, ops, options)

# Register standard types
require('./register')(ret)

ret.toMongo = ret['toMongo'] = require './to_mongo'
ret.toOutlets = ret['toOutlets'] = require './to_outlets'

