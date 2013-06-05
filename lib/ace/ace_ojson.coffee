OJSON = require '../ojson'
{extend, include} = require '../mixin'

module.exports = (Ace) ->
  OJSON.register 'Ace': Ace

  Ace.prototype.toJSON = ->
    OJSON.toOJSON [@db, @historyOutlets, @_name]

  Ace.fromJSON = (obj) ->
    new Ace obj[0], obj[1], obj[2]

