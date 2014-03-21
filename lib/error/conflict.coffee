OJSON = require 'ojson'
AceError = require './'

module.exports = class Conflict extends AceError
  constructor: (@version) ->

  toJSON: -> @version

  @fromJSON: (obj) -> new Conflict obj

OJSON.register 'Conflict': Conflict
