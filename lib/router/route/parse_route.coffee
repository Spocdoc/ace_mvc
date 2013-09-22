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
  formatFn = ''
  formatFn.push "var r = '', v;"
  lastIndex = 0

  shouldReplaceLhs = ''
  shouldReplaceRhs = ''

  regexPath = path.replace rPathPart, (match, type, key, value, optional, index) ->
    if fixed = path.substring(lastIndex, index)
      formatFn += "r += #{quote fixed};"
      shouldReplaceLhs += fixed
      shouldReplaceRhs += fixed
    formatFn += "if ((v = outlets[#{quote key}]) && null != (v = v.value)) r = r + #{quote type} + encodeURIComponent(v);"
    lastIndex = index + match.length

    keys.push key
    (if optional then optionalKeys else requiredKeys).push key

    regex = "#{type}#{value || '([^/]+?)'}"
    regex = "(?:#{regex})?" if optional

    shouldReplaceLhs += regex
    if optional
      shouldReplaceRhs += regex
    else
      shouldReplaceRhs += "#{type}\\#{keys.length}"

    regex

  if fixed = path.substr(lastIndex)
    formatFn += "r += #{quote fixed};"
    shouldReplaceLhs += fixed
    shouldReplaceRhs += fixed
  formatFn += "return r;"

  regexPath = new RegExp "^#{regexPath.replace(rEscape, '\\$1')}$"
  regexShouldReplace = new RegExp "^#{shouldReplaceLhs}##{shouldReplaceRhs}$".replace(rEscape, '\\$1')
  formatFn = new Function 'outlets', formatFn

  return [
    regexPath
    regexShouldReplace
    formatFn
  ]

