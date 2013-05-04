# derived from express

module.exports.parseRoute = do ->
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

  (path, keys, options={}) ->
    fn = []
    fn.push "var r = [];"
    lastI = 0

    path = path
      .replace(rPath, (match, slash='', format='', key, capture, optional, star, index) ->

        optional = !!optional || options.optional

        if optional
          if fixedLen = index - lastI
            fn.push """
              r.push("#{path.substr(lastI, fixedLen)}");
              """
          fn.push """
            if (p.#{key}) {
              r.push("#{slash}#{format}");
              r.push(p.#{key});
            }
            """
        else
          fn.push """
            r.push("#{path.substr(lastI, index - lastI)}#{slash}#{format}");
            r.push(p.#{key});
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
        ret += optional if optional
        ret += '(/*)?' if star
        ret)
      .replace(rEscape, '\\$1')
      .replace(rStar,'(.*)')

    fn.push """
      return r.join('');
    """

    [new RegExp('^' + path + '$', if options.sensitive then '' else 'i'),new Function('p', fn.join(''))]

