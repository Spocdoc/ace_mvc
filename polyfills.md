Requires polyfills given here

# Object.create

    if (!Object.create)
      Object.create = (o) ->
        F = ->
        F.prototype = o
        new F()
