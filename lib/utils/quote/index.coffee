regexQuotes = /(['\\])/g
regexNewlines = /([\n])/g

module.exports = (str) ->
  if typeof str is 'string'
    '\''+str.replace(regexQuotes,'\\$1').replace(regexNewlines,'\\n')+'\''
  else
    str

