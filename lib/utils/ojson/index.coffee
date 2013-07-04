{extend} = require '../mixin'

hasOwn = {}.hasOwnProperty

numSort = (a,b) ->
  c = +a
  d = +b
  if isFinite c
    if isFinite d
      c-d
    else
      false
  else if isFinite d
    true
  else
    a < b

# used to restore ojson object references
# (it has to keep track of whether it's ownProperty or not because it's added
# to objects that inherit a truthy _ojson)
class OJSONRef
  @name = 'OJSONRef'

  count = 0
  uniqueId = ->
    count = if count+1 == count then 0 else count+1
    "#{count}oj"
  cache = {}
  constructor: (@own, @id=uniqueId()) ->
  toJSON: -> {'o': @own, 'i': @id}
  @fromJSON: (obj) -> cache[obj['i']] || new OJSONRef(obj['o'], obj['i'])
  @add: (inst, obj) -> cache[inst.id] = obj
  @clear: ->
    # reset all the ojson objects
    for id, obj of cache when (j = obj?['_ojson']) and j instanceof OJSONRef
      if j.own
        obj['_ojson'] = true
      else
        delete obj['_ojson']
    cache = {}
    count = 0

module.exports = class OJSON
  @useArrays = true

  @register: (constructors...) ->
    for o in constructors
      if typeof o is 'object'
        for k,v of o
          v['_ojson'] = k
          @registry[k] = v
      else if o.name
        @registry[o.name] = o
    return


  @unregister: (constructors...) ->
    for o in constructors
      if typeof o is 'object'
        delete @registry[k] for k of o
      else if typeof o is 'string'
        delete @registry[o]
      else
        delete @registry[o.name]
    return

  @stringify: (obj) -> JSON.stringify @toOJSON obj

  @toOJSON: (obj) ->
    ret = @_toJSON obj if obj == ret = @_replacer '', obj
    OJSONRef.clear()
    ret

  @_toJSON: (obj) ->
    return obj if obj == null or typeof obj != 'object'
    ret = if OJSON.useArrays and Array.isArray obj then [] else {}

    # add ojson ref object
    if obj['_ojson']? and (!(own = hasOwn.call(obj,'_ojson')) or !(obj['_ojson'] instanceof OJSONRef))
      OJSONRef.add (obj['_ojson'] = new OJSONRef(own)), obj

    keys = Object.keys(obj)
    keys.sort(numSort)
    for k in keys
      v = obj[k]
      nv = @_replacer k, v
      if nv != v
        ret[k] = nv
        continue
      ret[k] = @_toJSON(v)
    ret

  @_replacer: (k, v) ->
    return v if v == null or typeof v isnt 'object'
    return @_replacer '', v['_ojson'] if hasOwn.call(v,'_ojson') && v['_ojson'] instanceof OJSONRef
    n = v.constructor['_ojson'] || v.constructor.name
    if not @registry[n]?
      return undefined if v.constructor != Object
      return v
    return @_toJSON v if OJSON.useArrays and Array.isArray v
    doc = {}
    doc["$#{n}"] = if v.toJSON? then v.toJSON() else @_toJSON v
    doc

  @fromOJSON: (obj) ->
    ret = @_fromOJSON obj
    OJSONRef.clear()
    ret

  @_fromOJSON: (obj) ->
    return obj if typeof obj isnt 'object' or obj == null

    res = if Array.isArray obj then [] else {}
    keys = Object.keys(obj)
    keys.sort(numSort)

    for k in keys
      v = @_fromOJSON obj[k]
      if k.charAt(0) is '$' and 'A' <= k.charAt(1) <= 'Z'
        if (constructor = @registry[k.substr(1)])?
          if constructor.fromJSON?
            res = constructor.fromJSON obj=v
          else
            res = new constructor obj=v
          break
      res[k] = v

    if obj['_ojson'] instanceof OJSONRef
      OJSONRef.add obj['_ojson'], res
    if res?['_ojson'] instanceof OJSONRef
      OJSONRef.add res['_ojson'], res

    res

  @parse: (str) -> @fromOJSON JSON.parse str

  @registry = {}

  register: @register
  unregister: @unregister
  stringify: @stringify
  fromOJSON: @fromOJSON
  _fromOJSON: @_fromOJSON
  toOJSON: @toOJSON
  _toJSON: @_toJSON
  _replacer: @_replacer
  parse: @parse

  constructor: ->
    unless this instanceof OJSON
      # "pkg" form
      return arguments[0].ojson = new OJSON
    else
      @useArrays = OJSON.useArrays
      @registry = Object.create OJSON.registry

OJSON.register Date, Array, 'Ref': OJSONRef
extend Array,
  fromJSON: (obj) ->
    inst = new this
    inst[k] = v for k,v of obj
    inst
