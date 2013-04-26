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

register = {}

# used to restore ojson object references
class OJSONRef
  count = 0
  uniqueId = ->
    "#{++count}js"
  cache = {}
  constructor: (obj) ->
    cache[@id = uniqueId()] = obj
  toJSON: -> @id
  @fromJSON: (id) -> cache[id] || id
  @add: (id, obj) -> cache[id] = obj
  @clear: ->
    cache = {}
    count = 0

module.exports = OJSON =

  parse: do ->
    fn = (k, v) ->
      return v if typeof v isnt 'object'
      try
        ojsonID = v._ojson
        break for key of v
        return v if not key or key[0] != '$'
        return v if not (constructor = register[key.substr(1)])?
        ojsonID = v[key]._ojson
        return v = constructor.fromJSON(v[key]) if constructor.fromJSON
        return v = new constructor(v[key])
      finally
        OJSONRef.add ojsonID, v if ojsonID
      
    (str) ->
      try
        JSON.parse str, fn
      finally
        OJSONRef.clear()

  stringify: do ->
    hasOwn = {}.hasOwnProperty

    fn = (k, v) ->
      return v if typeof v isnt 'object'
      return fn '', v._ojson if hasOwn.call(v,'_ojson') && v._ojson instanceof OJSONRef
      n = v.constructor._ojson || v.constructor.name
      if not register[n]?
        return undefined if v.constructor != Object
        return v
      doc = {}
      doc["$#{n}"] = if v.toJSON? then v.toJSON() else toJSON v
      doc

    toJSON = (obj) ->
      return obj if typeof obj != 'object'
      ret = {}
      obj._ojson = new OJSONRef(obj) if obj._ojson? and (!hasOwn.call(obj,'_ojson') or !(obj._ojson instanceof OJSONRef))
      for k, v of obj when hasOwn.call(obj, k)
        nv = fn k, v
        if nv != v
          ret[k] = nv
          continue
        ret[k] = toJSON(v)
      ret

    (obj) ->
      try
        ret = fn '', obj
        return JSON.stringify ret if ret != obj
        JSON.stringify toJSON obj
      finally
        OJSONRef.clear()


  # can register custom names with the form {name: constructor}. This adds a
  # `_ojson` property to the constructor. For custom names, prefer starting
  # with an uppercase (no $ prefix necessary)
  register: do ->

    addToSet = (set,k,v) ->
      throw new Error("OJSON: can't register anonymous functions") if not k? or not k.length
      throw new Error("OJSON: multiple instance of same type #{k} in registration list") if set[k]?
      throw new Error("OJSON: already registered type #{k}") if register[k]?
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
      register[k] = c for k,c of set
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

