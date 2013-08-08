class ObjectID
  @name = 'ObjectID'

  constructor: (@hex) ->
    if !@hex?
      id = []
      `for (var i = 0; i < 24; ++i) id[i] = (Math.random()*16|0).toString(16);`
      @hex = id.join('')

  toString: -> @hex
  'toJSON': -> @hex

class DBRef
  @name = 'DBRef'
  constructor: (@namespace, @oid) ->
  toString: -> "#{@constructor.name} [#{@namespace}]:[#{@oid}]"

window['mongo'] =
  'ObjectID': ObjectID
  'DBRef': DBRef

