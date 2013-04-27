OJSON = require '../ojson/ojson'
{extend, include} = require '../mixin/mixin'

# Note that this does not serialize anything in the HistoryObjects other than
# the dataStore so if outlets are marked `noInherit` at certain points, this
# isn't preserved, and the outlets themselves are not preserved

module.exports = (HistoryOutlets) ->
  OJSON.register HistoryOutlets

  HistoryOutlets.prototype.toJSON = -> OJSON.toOJSON @dataStore

  HistoryOutlets.fromJSON = (obj) -> new HistoryOutlets obj

