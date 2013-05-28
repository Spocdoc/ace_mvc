require '../polyfill'

class Registry
  constructor: ->
    @r = Object.create null

  find: (obj) ->
    return false unless reg = @r[obj.constructor.name]
    (return r.d if obj instanceof r.type) for r in reg
    false

  add: (constructor, data) ->
    (@r[constructor.name] ||= []).push
      type: constructor
      d: data
    this

module.exports = Registry
