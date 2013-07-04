# outlets are structured with _ equal to the outlet at that value, otherwise
# nested in objects
clone = require '../clone'

translate = (doc, registry) ->
  return r.translate doc if r = registry?.find doc
  clone doc

setDescendants = (outlets, doc, registry) ->
  set v, doc?[k], registry for k,v of outlets when k isnt '_'
  return

set = (outlets, doc, registry) ->
  outlets['_'].set(translate doc, registry) if outlets['_']
  set v, doc?[k], registry for k,v of outlets when k isnt '_'
  return

patchArray = (outlets, ops, arr, registry) ->
  srcIndex = 0
  dstIndex = 0

  changed = arr.length

  outlets['_'].set(translate arr, registry) if outlets['_']

  for op in ops
    if (index = op['i']) < 0
      break if srcIndex != dstIndex
      # works because all ops at the end are either push or pop
      # if conditional insert, won't matter: it'll be a string and the outlet
      # flow will stop immediately
      --changed
    else
      while dstIndex < index
        if srcIndex != dstIndex
          set ok, arr[dstIndex], registry if (ok = outlets[dstIndex])?
        ++srcIndex
        ++dstIndex

      unless op['o'] is -1
        patch ok, op, arr[dstIndex], registry if (ok = outlets[dstIndex])?

      switch op['o']
        when -1 then ++srcIndex
        when 1 then ++dstIndex
        else
          ++dstIndex
          ++srcIndex

  if srcIndex != dstIndex || (dstIndex = changed) < arr.length
    for i,ok of outlets when i >= dstIndex
      set ok, arr[i], registry

  return

patch = (ok, op, dk, registry) ->
  switch op['o']
    when -1, 1
      set ok, dk, registry
    else
      if !dk? or typeof dk in ['string','number']
        set ok, dk, registry
      else if Array.isArray dk
        patchArray ok, op['d'], dk, registry
      else
        patchOutlets ok, op['d'], dk, registry
  return

module.exports = patchOutlets = (outlets, ops, doc, registry) ->
  return unless ops and ops.length and outlets
  outlets['_'].set(translate doc, registry) if outlets['_']

  for op in ops
    unless op['k']?
      switch op['o']
        when -1, 1
          setDescendants outlets, doc, registry
        else
          # this will call outlets['_'].set again, but that's OK. this is
          # evaluated in a Cascade.Block
          patchOutlets outlets, op['d'], doc, registry
    else
      o = outlets
      d = doc

      s = op['k'].split '.'
      `for (var j=0, je = s.length-1; j < je && o; ++j) {
        if (d != null) d = d[s[j]];
        if (o = o[s[j]]) if (o['_']) o['_'].set(translate(d,registry));
      }`
      continue unless o
      k = s[je]
      dk = d?[k]

      patch ok, op, dk, registry if (ok = o[k])?
  return

