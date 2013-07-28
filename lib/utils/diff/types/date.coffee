module.exports = (from, to) ->
  fromTime = from.getTime()
  toTime = to.getTime()
  return false if fromTime == toTime
  toTime - fromTime

module.exports.patch = module.exports['patch'] = (obj, diff) ->
  obj.setTime(obj.getTime() + diff)
  obj
