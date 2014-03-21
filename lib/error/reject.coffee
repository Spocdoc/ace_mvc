AceError = require './'
OJSON = require 'ojson'

module.exports = class Reject extends AceError
  constructor: (@code) ->

  toJSON: -> @code
  @fromJSON: (obj) -> new Reject obj

OJSON.register 'Reject': Reject

