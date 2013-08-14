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

    Array.prototype['some'] ?= (fn) ->
      for v in @
        return true if fn(v)
      false

# Array.indexOf

    Array.prototype['indexOf'] ?= (elem) ->
      `for (var i = 0, iE = this.length; i < iE; ++i) if (this[i] === elem) return i;`
      -1

# String.trim

    String.prototype['trim'] ?= do ->
      regex = /^\s+|\s+$/g
      -> @replace(regex, '')

# String.startsWith

    String.prototype['startsWith'] ?= (str) ->
      @lastIndexOf(str,0) is 0

    String.prototype['endsWith'] ?= (str) ->
      @indexOf(str, @length - str.length) isnt -1

# Date.now

    Date['now'] ?= (new Date()).getTime()

# IE<9 doesn't have names on functions

    unless Array.name is 'Array'
      Array.name = 'Array'
      Object.name = 'Object'
      Date.name = 'Date'
      Number.name = 'Number'
      String.name = 'String'

# RegExp escape

    RegExp['escape'] ?= do ->
      regex = /[-\/\\^$*+?.()|[\]{}]/g
      (str) -> return str.replace(regex, '\\$&')

    # IE considers \u00a0 to be non-space
    RegExp['whitespace'] = spaceChars = " \t\r\n\u00a0"
    RegExp['_s'] = "[#{spaceChars}]"
    RegExp['_S'] = "[^#{spaceChars}]"

