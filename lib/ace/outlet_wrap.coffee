Outlet = require 'outlet'

onOrig = $['fn']['on']
$['fn']['on'] = ->
  j = arguments.length-1
  while j > 0
    if typeof (fn = arguments[j]) is 'function'
      arguments[j] = Outlet.block fn unless fn.inblock
      break
    --j
  onOrig.apply this, arguments
