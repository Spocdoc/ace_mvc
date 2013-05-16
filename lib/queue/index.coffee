# inspired by <http://tomswitzer.net/2011/02/super-simple-javascript-queue/>

max = 9007199254740992

module.exports = ->
  s = e = max-10 # for testing wrap-around
  a = []

  fn = (v) ->
    if v is undefined
      if s isnt e
        r = a[s]
        delete a[s]
        s = if s+1 is max then 0 else s+1
      return r
    else
      a[e] = v
      e = if e+1 is max then 0 else e+1
      return this

  fn.empty = ->
    s == e

  fn.length = ->
    `var len = s - e; return len < 0 ? -len : len;`
    return

  fn.unshift = (v) ->
    if --s < 0
      s = s + max
    a[s] = v
    return this

  fn
