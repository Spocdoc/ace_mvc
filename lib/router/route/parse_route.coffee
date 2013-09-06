# similar to express routing
{quote} = require 'lodash-fork'

rPathPart = ///
  ([/.])            # type
  :(\w+)            # key
  (\(.*?\))?        # value
  (\?)?             # optional
///g

rEscape = ///
  ([/.])
///g

module.exports = (path, keys, optionalKeys, requiredKeys) ->
  formatFn = []
  formatFn.push "var r = [], v;"
  lastIndex = 0

  shouldReplaceLhs = []
  shouldReplaceRhs = []

  regexPath = path.replace rPathPart, (match, type, key, value, optional, index) ->
    if fixed = path.substring(lastIndex, index)
      formatFn.push "r.push(#{quote fixed});"
      shouldReplaceLhs.push fixed
      shouldReplaceRhs.push fixed
    formatFn.push "if ((v = outlets[#{quote key}]) && null != (v = v.value)) r.push(#{quote type}, encodeURIComponent(v));"
    lastIndex = index + match.length

    keys.push key
    (if optional then optionalKeys else requiredKeys).push key

    regex = "#{type}#{value || '([^/]+?)'}"
    regex = "(?:#{regex})?" if optional

    shouldReplaceLhs.push regex
    if optional
      shouldReplaceRhs.push "(?:#{type}\\#{keys.length}|)"
    else
      shouldReplaceRhs.push "#{type}\\#{keys.length}"

    regex

  if fixed = path.substr(lastIndex)
    formatFn.push "r.push(#{quote fixed});"
    shouldReplaceLhs.push fixed
    shouldReplaceRhs.push fixed
  formatFn.push "return r.join('');"

  regexPath = new RegExp "^#{regexPath.replace(rEscape, '\\$1')}$"
  regexShouldReplace = new RegExp "^#{shouldReplaceLhs.join('')}##{shouldReplaceRhs.join('')}$".replace(rEscape, '\\$1')
  formatFn = new Function 'outlets', formatFn.join('')

  return [
    regexPath
    regexShouldReplace
    formatFn
  ]

