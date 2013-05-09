{diff: diffArr, apply: applyArr} = require('./array')

Array.prototype.diff = (to, options) ->
  res = diffArr(@,to,options)
  return false unless res.length
  res

Array.prototype.applyDiff = (diff, options) ->
  res = applyArr(@, diff, options)
  @splice(0)
  @[k] = v for v,k in res
  this

Date.prototype.diff = (to, options) ->
  fromTime = @getTime()
  toTime = to.getTime()
  return false if fromTime == toTime
  toTime - fromTime

Date.prototype.applyDiff = (diff, options) ->
  @setTime(@getTime() + diff)
  this

types = ['string','number','object']

diffNumber = (from, to, options) ->
  d = to - from
  if d then d else false

applyNumber = (obj, diff, options) ->
  obj += diff

diffString = (from, to, options) ->
  # TODO
  return false if to == from
  to

applyString = (obj, diff, options) ->
  # TODO
  diff

diffObj = (from, to, options) ->
  res = []

  for k,v of from
    if (spec = diff(v, to[k], options, k)) != false
      res.push spec
  
  for k,v of to when !from[k]?
    res.push {o: 1, k: k, v: v}

  return if res.length then res else false

diff = (from, to, options = {}, key) ->
  if typeof from isnt typeof to
    spec = {}
    if key?
      spec.k = key
      res = spec
    else
      res = [spec]

    if typeof to in types
      spec.o = 1
      spec.v = to
    else
      spec.o = -1

    return res

  # handle immutable objects separately
  switch typeof from
    when 'number'
      d = diffNumber(from, to, options)
    when 'string'
      d = diffString(from, to, options)
    else
      if from.diff?
        d = from.diff to, options
      else
        d = diffObj(from, to, options)

  return false if d == false
  return { o: 0, k: key, d: d } if key?
  d

applyObj = (obj, ops, options) ->
  for op in ops
    switch op.o
      when -1
        delete obj[op.k]
      when 1
        obj[op.k] = op.v
      else
        obj[op.k] = applyDiff(obj[op.k], op.d, options)
  obj


applyDiff = (obj, ops, options) ->
  # handle immutable objects separately
  switch typeof obj
    when 'number'
      applyNumber(obj, ops, options)
    when 'string'
      applyString(obj, ops, options)
    else
      if obj.applyDiff?
        obj.applyDiff(ops, options)
      else
        applyObj(obj, ops, options)

module.exports = (from, to, options = {}) ->
  options.deep = diff
  options.move ?= true

  diff(from, to, options)

module.exports.applyDiff = (obj, ops, options = {}) ->
  options.deep = applyDiff
  applyDiff(obj, ops, options)

