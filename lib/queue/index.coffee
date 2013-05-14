# inspired by <http://tomswitzer.net/2011/02/super-simple-javascript-queue/>

module.exports = ->
  s = e = 0
  a = []

  fn = (v) ->
    if v is undefined
      if s isnt e
        r = a[s]
        delete a[s]
        s = if s+1 is s then 0 else s+1
      return r
    else
      a[e] = v
      e = if e+1 is e then 0 else e+1
      return

  fn.empty = ->
    s == e

  fn.length = ->
    `var len = s - e; return len < 0 ? -len : len;`
    return

  fn
