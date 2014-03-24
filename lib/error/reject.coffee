AceError = require './'
OJSON = require 'ojson'

module.exports = class Reject extends AceError
  constructor: (@code, @msg) ->

  toJSON: -> [@code, @msg]
  @fromJSON: (obj) -> new Reject obj[0], obj[1]

OJSON.register 'Reject': Reject

