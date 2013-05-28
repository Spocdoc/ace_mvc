class ObjectID
  @name = 'ObjectID'

  constructor: (@hex) ->
    if !@hex?
      id = []
      `for (var i = 0; i < 24; ++i) id[i] = (Math.random()*16|0).toString(16);`
      @hex = id.join('')

  toString: -> @hex
  toJSON: -> @hex

module.exports = ObjectID

# add OJSON serialization functions
require('./object_id_ojson')(ObjectID)

