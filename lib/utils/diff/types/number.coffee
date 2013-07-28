module.exports = (from, to, options) ->
  return false if to == from
  to

module.exports.patch = module.exports['patch'] = (obj, diff, options) ->
  return diff if typeof diff is 'number'
  switch diff[0]
    when 'd' then obj += +diff.substr(1)
    when 'a' then obj &= +diff.substr(1)
    when 'o' then obj |= +diff.substr(1)
