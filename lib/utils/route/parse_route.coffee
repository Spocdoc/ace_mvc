# similar to express routing

rPath = ///
  (/)?              # slash
  (.)?              # format
  :(\w+)            # key
  (?:(\(.*?\)))?    # capture
  (\?)?             # optional
  (\*)?             # star
///g

rEscape = ///
  ([/.])
///g

rStar = ///
  \*
///g

module.exports = (path, keys) ->
  fn = []
  fn.push "var r = [], v;"
  lastI = 0

  original = path

  path = path
    .replace(rPath, (match, slash='', format='', key, capture, optional, star, index) ->

      optional = !!optional

      if fixedLen = index - lastI
        fn.push """
          r.push("#{path.substr(lastI, fixedLen)}");
          """
      fn.push """
        if (p.#{key} != null && (v = p.#{key}['value']) != null) {
          r.push("#{slash}#{format}");
          r.push(encodeURIComponent(v));
        }
        """

      lastI = index + match.length

      keys.push({ name: key, optional: optional })

      ret = ''
      ret += slash if not optional

      group = ''
      group += slash if optional
      group += format
      if capture
        group += capture
      else
        if format
          group += '([^/.]+?)'
        else
          group += '([^/]+?)'
      group = "(?:#{group})" if optional and (format != '' or slash != '')

      ret += group
      ret += '?' if optional
      ret += '(/*)?' if star
      ret)

  if original.length > lastI
    fn.push """
      r.push("#{original.substr(lastI)}");
      """

  fn.push """
    return r.join('');
  """

  path = path
    .replace(rEscape, '\\$1')
    .replace(rStar,'(.*)')

  [new RegExp('^' + path + '$'),new Function('p', fn.join(''))]

