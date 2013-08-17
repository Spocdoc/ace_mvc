domUtils = require '../../../utils/dom_utils'

$['fn']['extend']
  'childNumber': -> domUtils.getChildIndex @[0]
  'name': -> (''+@[0].nodeName).toLowerCase()


