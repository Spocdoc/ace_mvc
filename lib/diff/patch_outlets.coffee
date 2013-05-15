# outlets are structured with _ equal to the outlet at that value, otherwise
# nested in objects

clone = require '../clone'

setDescendants = (outlets, doc) ->
  set v, doc?[k] for k,v of outlets when k isnt '_'
  return

set = (outlets, doc) ->
  outlets._.set(clone doc) if outlets._?
  set v, doc?[k] for k,v of outlets when k isnt '_'
  return

patchArray = (outlets, ops, arr) ->
  srcIndex = 0
  dstIndex = 0

  changed = arr.length

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
          set ok, arr[dstIndex] if (ok = outlets[dstIndex])?
        ++srcIndex
        ++dstIndex

      unless op['o'] is -1
        patch ok, op, arr[dstIndex] if (ok = outlets[dstIndex])?

      switch op['o']
        when -1 then ++srcIndex
        when 1 then ++dstIndex
        else
          ++dstIndex
          ++srcIndex

  if srcIndex != dstIndex || (dstIndex = changed) < arr.length
    for i,ok of outlets when i >= dstIndex
      set ok, arr[i]

  return

patch = (ok, op, dk) ->
  switch op['o']
    when -1, 1
      set ok, dk
    else
      if !dk? or typeof dk in ['string','number']
        set ok, dk
      else if Array.isArray dk
        patchArray ok, op['d'], dk
      else
        patchOutlets ok, op['d'], dk
  return


module.exports = patchOutlets = (outlets, ops, doc) ->
  return unless ops and ops.length
  outlets._.set(clone doc) if outlets._?

  for op in ops
    unless op['k']?
      switch op['o']
        when -1, 1
          setDescendants outlets, doc
        else
          # this will call outlets._.set again, but that's OK. this is
          # evaluated in a Cascade.Block
          patchOutlets(outlets, op['d'], doc)
    else
      patch ok, op, doc[op['k']] if (ok = outlets[op['k']])?
  return

