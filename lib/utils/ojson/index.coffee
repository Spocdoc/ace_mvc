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

module.exports = class OJSON
  @useArrays = true

  @register: (constructors...) ->
    for o in constructors
      if typeof o is 'object'
        for name,constructor of o
          constructor['_ojson'] = name
          throw new Error("already registered [#{name}]") if current = @registry[name] and current isnt constructor
          @registry[name] = constructor
      else if o.name
        @registry[o.name] = o
      else throw new Error("can't register anonymous types")
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
    ret

  @_toJSON: (obj) ->
    return obj if obj == null or typeof obj != 'object'
    ret = if OJSON.useArrays and Array.isArray obj then [] else {}
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
    n = v.constructor['_ojson'] || v.constructor.name
    if not @registry[n]?
      return v['toOJSON']?() if v.constructor != Object
      return v
    return @_toJSON v if OJSON.useArrays and Array.isArray v
    doc = {}
    doc["$#{n}"] = if v.toJSON? then v.toJSON() else @_toJSON v
    doc

  @fromOJSON: (obj) ->
    return obj if typeof obj isnt 'object' or obj == null

    res = if Array.isArray obj then [] else {}

    for k,v of obj
      v = @fromOJSON v
      if k.charAt(0) is '$' and 'A' <= k.charAt(1) <= 'Z'
        if (constructor = @registry[k.substr(1)])?
          if constructor.fromJSON?
            res = constructor.fromJSON obj=v
          else
            res = new constructor obj=v
          break
      res[k] = v

    res

  @parse: (str) -> str && @fromOJSON JSON.parse str

  @registry = {}

  @copyKeys =
    fromJSON: (obj) ->
      inst = new this
      inst[k] = v for k,v of obj
      inst

  register: @register
  unregister: @unregister
  stringify: @stringify
  fromOJSON: @fromOJSON
  toOJSON: @toOJSON
  _toJSON: @_toJSON
  _replacer: @_replacer
  parse: @parse

  constructor: ->
    @useArrays = OJSON.useArrays
    @registry = Object.create OJSON.registry

OJSON.register Date, Array
extend Array, OJSON.copyKeys
