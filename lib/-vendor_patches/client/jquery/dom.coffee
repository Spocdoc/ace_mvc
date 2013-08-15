domUtils = require '../../../utils/dom_utils'

$['fn']['extend']
  'childNumber': -> domUtils.getChildIndex @[0]
  'type': -> (''+@[0].nodeType).toLowerCase()


