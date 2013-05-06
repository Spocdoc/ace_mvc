{include, extend} = require '../mixin/mixin'

# "Object"-based JSON 
# converts registered types to a notation like `{$Date: "..."}`
#
# Array JSON notation is not used because there are no arrays in JavaScript
# (JavaScript Arrays can have arbitrary keys, missing values and are
# implemented as hash tables). Instead Arrays become more verbose but more
# robust: `{$Array: {0: 'first', 1: 'second'}}`.
#
# register a new type with OJSON.register <constructor>
#
# if the type implements a class method fromJSON, it'll be used as a factory
# for example:
#
#    var Foo = function (value) { this._value = value; };
#    Foo.prototype.toJSON = function() {  return this._value; };
#    Foo.fromJSON = function(arg) { return new this(arg); };
#    OJSON.register(Foo);
#
# if the type does not implement fromJSON, its JSON representation (either from
# toJSON or an object containing all its keys) is passed to the constructor:
# 
#    // when restored, will call new Foo(value)
#    var Foo = function (value) { this._value = value; };
#    Foo.prototype.toJSON = function() {  return this._value; };
#    OJSON.register(Foo);
#
# This works well for other types. Date, for instance, has a toJSON(), whose
# value can be passed to the constructor to re-create it.
#
# Note that the reference mechanism requires that objects are defined before
# they're referenced, so it's sensitive to the order of key traversal in the
# parse function
#
# Also note that you can't serialize values that are set to void 0. It's
# possible to send it, but because JSON.parse treats a void 0 return value from
# its reviver as "remove from the object", reviving void 0 values would require
# re-implementing JSON.parse.

registry = {}

# used to restore ojson object references
# (it has to keep track of whether it's ownProperty or not because it's added
# to objects that inherit a truthy _ojson)
class OJSONRef
  count = 0
  uniqueId = -> "#{++count}oj"
  cache = {}
  constructor: (@own, @id=uniqueId()) ->
  toJSON: -> {o: @own, i: @id}
  @fromJSON: (obj) -> cache[obj.i] || new OJSONRef(obj.o, obj.i)
  @add: (inst, obj) -> cache[inst.id] = obj
  @clear: ->
    # reset all the ojson objects
    for id, obj of cache when (j = obj?._ojson) and j instanceof OJSONRef
      if j.own
        obj._ojson = true
      else
        delete obj._ojson
    cache = {}
    count = 0

module.exports = OJSON =

  parse: do ->
    fn = (k, v) ->
      return v if v == null or typeof v isnt 'object'
      try
        ojsonRef = v._ojson
        break for key of v
        return v if not key or key[0] != '$'
        return v if not (constructor = registry[key.substr(1)])?
        ojsonRef = v[key]?._ojson
        return v = constructor.fromJSON(v[key]) if constructor.fromJSON
        return v = new constructor(v[key])
      finally
        OJSONRef.add ojsonRef, v if ojsonRef
      
    (str) ->
      try
        JSON.parse str, fn
      finally
        OJSONRef.clear()

  stringify: (obj) -> JSON.stringify OJSON.toOJSON obj

  toOJSON: do ->
    hasOwn = {}.hasOwnProperty

    fn = (k, v) ->
      return v if v == null or typeof v isnt 'object'
      return fn '', v._ojson if hasOwn.call(v,'_ojson') && v._ojson instanceof OJSONRef
      n = v.constructor._ojson || v.constructor.name
      if not registry[n]?
        return undefined if v.constructor != Object
        return v
      doc = {}
      doc["$#{n}"] = if v.toJSON? then v.toJSON() else toJSON v
      doc

    toJSON = (obj) ->
      return obj if obj == null or typeof obj != 'object'
      ret = {}

      # add ojson ref object
      if obj._ojson? and (!(own = hasOwn.call(obj,'_ojson')) or !(obj._ojson instanceof OJSONRef))
        OJSONRef.add (obj._ojson = new OJSONRef(own)), obj

      for k,v of obj when hasOwn.call(obj, k)
        nv = fn k, v
        if nv != v
          ret[k] = nv
          continue
        ret[k] = toJSON(v)
      ret

    (obj) ->
      try
        ret = fn '', obj
        return ret if ret != obj
        toJSON obj
      finally
        OJSONRef.clear()


  # can register custom names with the form {name: constructor}. This adds a
  # `_ojson` property to the constructor. For custom names, prefer starting
  # with an uppercase (no $ prefix necessary)
  register: do ->

    addToSet = (set,k,v) ->
      throw new Error("OJSON: can't register anonymous functions") if not k? or not k.length
      throw new Error("OJSON: multiple instance of same type #{k} in registration list") if set[k]?
      throw new Error("OJSON: already registered type #{k}") if registry[k]?
      set[k] = v

    (constructors...) ->
      set = {}

      # get keys and check existence
      for o in constructors
        if typeof o is 'object'
          for k,v of o
            v._ojson = k
            addToSet(set, k, v)
        else
          addToSet(set, o.name, o)

      # add types
      registry[k] = c for k,c of set
      return

  unregister: (constructors...) ->
    for o in constructors
      if typeof o is 'object'
        delete registry[k] for k of o
      else if typeof o is 'string'
        delete registry[o]
      else
        delete registry[o.name]
    return

  # use by including this into classes where instead of calling the constructor
  # with the argument, a new instance should be constructed and the properties
  # copied over
  copyKeys:
    fromJSON: (obj) ->
      inst = new this
      inst[k] = v for k,v of obj
      inst

OJSON.register Date, Array, OJSONRef
extend Array, OJSON.copyKeys
