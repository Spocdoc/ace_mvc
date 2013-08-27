ELEMENT_NODE = 1
ATTRIBUTE_NODE = 2
TEXT_NODE = 3
COMMENT_NODE = 8
DOCUMENT_NODE = 9
DOCUMENT_TYPE_NODE = 10
DOCUMENT_FRAGMENT_NODE = 11

$.FocusGroup = require './focus_group'

$.isText = (d) ->
  d?.nodeType is TEXT_NODE

$.getChildIndex = (e) ->
  k = 0
  k++ while e = e.previousSibling
  k

$.isElement = (d) ->
  d?.nodeType is ELEMENT_NODE
