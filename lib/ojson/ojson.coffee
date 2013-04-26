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
module.exports = OJSON =
  _types: {}

  parse: do ->
    fn = (k, v) ->
      return v if typeof v isnt 'object'
      break for key of v
      return v if not key or key[0] != '$'
      return v if not (constructor = OJSON._types[key.substr(1)])?
      return constructor.fromJSON v[key] if constructor.fromJSON
      return new constructor v[key]
      
    (str) -> JSON.parse str, fn

  stringify: do ->
    fn = (k, v) ->
      return v if typeof v isnt 'object'
      n = v.constructor._ojson || v.constructor.name
      if not OJSON._types[n]?
        return undefined if v.constructor != Object
        return v
      doc = {}
      doc["$#{n}"] = if v.toJSON? then v.toJSON() else toJSON v
      doc

    hasOwn = {}.hasOwnProperty

    toJSON = (obj) ->
      return obj if typeof obj != 'object'
      ret = {}
      for k, v of obj when hasOwn.call(obj, k)
        nv = fn k, v
        if nv != v
          ret[k] = nv
          continue
        ret[k] = toJSON(v)
      ret

    (obj) ->
      ret = fn '', obj
      return JSON.stringify ret if ret != obj
      JSON.stringify toJSON obj

  # can register custom names with the form {name: constructor}. This adds a
  # `_ojson` property to the constructor. For custom names, prefer starting
  # with an uppercase (no $ prefix necessary)
  register: do ->

    addToSet = (set,k,v) ->
      throw new Error("OJSON: can't register anonymous functions") if not k? or not k.length
      throw new Error("OJSON: multiple instance of same type #{k} in registration list") if set[k]?
      throw new Error("OJSON: already registered type #{k}") if OJSON._types[k]?
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
      OJSON._types[k] = c for k,c of set
      return

  # use by including this into classes where instead of calling the constructor
  # with the argument, a new instance should be constructed and the properties
  # copied over
  copyKeys:
    fromJSON: (obj) ->
      inst = new this
      inst[k] = v for k,v of obj
      inst

OJSON.register Date, Array
extend Array, OJSON.copyKeys

