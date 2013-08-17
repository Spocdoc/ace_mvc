module.exports =

  escape: (html, encode) ->
    html.replace((if not encode then /&(?!#?\w+;)/g else /&/g), "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace /'/g, "&#39;"

  replace: (regex, opt) ->
    regex = regex.source
    opt = opt or ""
    self = (name, val) ->
      return new RegExp(regex, opt)  unless name
      val = val.source or val
      val = val.replace(/(^|[^\[])\^/g, "$1")
      regex = regex.replace(name, val)
      self

  merge: (obj) ->
    i = 1
    while i < arguments.length
      target = arguments[i]
      for key of target
        obj[key] = target[key]  if Object::hasOwnProperty.call(target, key)
      i++
    obj


