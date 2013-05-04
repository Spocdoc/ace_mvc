
# Object.create

    Object.create ?= (o) ->
      F = ->
      F.prototype = o
      new F()

# Array.isArray

    Array.isArray ?= (o) ->
      '' + o != o and {}.toString.call(o) == '[object Array]'


# String.trim

    String.prototype.trim ?= do ->
      regex = /^\s+|\s+$/g
      -> @replace(regex, '')

# RegExp.escape

    RegExp.escape ?= do ->
      regex = /[-\/\\^$*+?.()|[\]{}]/g
      (str) -> return str.replace(regex, '\\$&')
