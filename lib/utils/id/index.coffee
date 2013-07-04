count = 0

module.exports = ->
  count = if count+1 == count then 0 else count+1
  "#{count}-Id"
