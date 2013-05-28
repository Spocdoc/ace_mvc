# NOTE: some of this is written in a strange way (use of quotes) to accommodate the (terrible) design decisions of Google's Closure compiler

# Object.create

    Object['create'] ?= (o) ->
      F = ->
      F.prototype = o
      new F()

# Object.keys

    Object['keys'] ?= (o) ->
      k for k of o when {}.hasOwnProperty.call(o,k)

# Array.isArray

    Array['isArray'] ?= (o) ->
      '' + o != o and {}.toString.call(o) == '[object Array]'

# Array.prototype.some

    Array['prototype']['some'] ?= (fn) ->
      for v in @
        return true if fn(v)
      false

# String.trim

    String['prototype']['trim'] ?= do ->
      regex = /^\s+|\s+$/g
      -> @replace(regex, '')

# RegExp.escape

    RegExp['escape'] ?= do ->
      regex = /[-\/\\^$*+?.()|[\]{}]/g
      (str) -> return str.replace(regex, '\\$&')

# Date.now

    Date['now'] ?= (new Date()).getTime()

# IE<9 doesn't have names on functions

    unless Array.name is 'Array'
      Array.name = 'Array'
      Object.name = 'Object'
      Date.name = 'Date'
