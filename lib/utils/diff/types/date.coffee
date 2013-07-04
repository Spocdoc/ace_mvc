module.exports =
  diff: (from, to) ->
    fromTime = from.getTime()
    toTime = to.getTime()
    return false if fromTime == toTime
    toTime - fromTime
  patch: (obj, diff) ->
    obj.setTime(obj.getTime() + diff)
    obj
