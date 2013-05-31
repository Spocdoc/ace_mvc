
set = (res, k, v) ->
  (res['$set'] ||= {})[k] = v
  return
unset = (res, k) ->
  (res['$unset'] ||= {})[k] = 1
  return
inc = (res, k, delta) ->
  (res['$inc'] ||= {})[k] = delta
  return
bitOr = (res, k, v) ->
  ((res['$bit'] ||= {})[k] ||= {})['or'] = v
  return
bitAnd = (res, k, v) ->
  ((res['$bit'] ||= {})[k] ||= {})['and'] = v
  return

possibleEach = (p, k, v) ->
  if a = p[k]
    if e = a['$each']
      e.push v
    else
      p[k] = { '$each': [a, v] }
  else
    p[k] = v
  return

push = (res, k, v) ->
  possibleEach res['$push'] ||= {}, k, v
  return

addToSet = (res, k, v) ->
  possibleEach res['$addToSet'] ||= {}, k, v
  return

pop = (res, k, v) ->
  (res['$pop'] ||= {})[k] = v
  return

POP_END = 1
POP_BEG = 2
PUSH_END = 3
ADD_TO_SET = 4
MOD = 5

fromArray = (res, ops, to, prefix) ->
  # mongo has very limited array modifications:
  #   - pop *one* from end OR pop *one* from beginning
  #  OR
  #   - push any number to end
  #  OR
  #   - addToSet
  #  OR
  #   - modification of any number of contained elements
  mode = 0
  len = to.length
  pushEnd = []
  pushEndStart = len

  for o in ops
    switch o['o']
      when -1
        return false if mode != 0
        return false if o['r']? or o['p']?
        if o['i'] == 0
          mode = POP_BEG
        else
          return false unless o['i'] in [len, -1]
          mode = POP_END

      when 1
        if o['u']?
          return false if (mode ||= ADD_TO_SET) != ADD_TO_SET
        else
          return false if (mode ||= PUSH_END) != PUSH_END
          return false unless o['v']?
          if o['i'] < 0
            pushEnd[--pushEndStart] = 1
          else
            pushEndStart = o['i'] if o['i'] < pushEndStart
            pushEnd[o['i']] = 1

      else
        return false if (mode ||= MOD) != MOD

  switch mode
    when POP_BEG
      pop(res, prefix, -1)
    when POP_END
      pop(res, prefix, 1)
    when PUSH_END
      `for (var i = pushEndStart; i < len; ++i)
        if (pushEnd[i] == null)
          return false;`
      `for (var i = pushEndStart; i < len; ++i)
        push(res, prefix, to[i]);`
    when ADD_TO_SET
      addToSet(res, prefix, o['u']) for o in ops
    when MOD
      tomongo(res, o['d'], to[o['i']], prefix + "." + o['i'])

  return true

tomongo = (res, ops, to, prefix) ->
  for op in ops
    k = op['k']
    sk = (if prefix then prefix+'.' else '') + k

    t = to
    s = k.split '.'
    `for (var j=0, je = s.length-1; j < je; ++j) t = t[s[j]];`
    k = s[s.length-1]

    switch op['o']
      when 1
        set(res, sk, t[k])
      when -1
        return undefined unless k?
        unset(res, sk)
      else
        switch typeof t[k]
          when 'string'
            set(res, sk, t[k])
          when 'number'
            if typeof (d = op['d']) is 'number'
              set(res, sk, t[k])
            else
              v = +d.substr(1)
              switch d[0]
                when 'd' then inc(res, sk, v)
                when 'o' then bitOr(res, sk, v)
                when 'a' then bitAnd(res, sk, v)
          else
            if Array.isArray(t[k])
              unless fromArray(res, op['d'], t[k], sk)
                set(res, sk, t[k])
            else
              tomongo(res, op['d'], t[k], sk)
  return


module.exports = (ops, to) ->
  res = {}
  tomongo(res, ops, to, '')
  res

