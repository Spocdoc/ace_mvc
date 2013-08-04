dom = require '../dom'

#
# derived from selection.js Copyright (c) 2011-12 Tim Cameron Ryan. MIT licensed.
#

getBoundary = (textRange, atStart, result) ->
  # We can get the "parentElement" of a cursor (an endpoint of a TextRange).
  # Create an anchor (throwaway) element and move it from the end of the element
  # progressively backward until the text range of the anchor's contents
  # meets or exceeds our original cursor.
  cursorNode = global.document.createElement("a")
  cursor = textRange.duplicate()
  cursor.collapse atStart
  parent = cursor.parentElement()
  loop
    parent.insertBefore cursorNode, cursorNode.previousSibling
    cursor.moveToElementText cursorNode
    break  unless cursor.compareEndPoints(((if atStart then "StartToStart" else "StartToEnd")), textRange) > 0 and (cursorNode.previousSibling?)
  
  # When we exceed or meet the cursor, we've found the node our cursor is
  # anchored on.
  if cursor.compareEndPoints(((if atStart then "StartToStart" else "StartToEnd")), textRange) is -1 and cursorNode.nextSibling
    
    # This node can be a text node...
    cursor.setEndPoint ((if atStart then "EndToStart" else "EndToEnd")), textRange
    node = cursorNode.nextSibling
    offset = cursor.text.length
  else
    
    # ...or an element.
    node = cursorNode.parentNode
    offset = dom.getChildIndex(cursorNode)
  
  # Remove our dummy node and return the anchor.
  cursorNode.parentNode.removeChild cursorNode
  if atStart
    result.startContainer = node
    result.startOffset = offset
  else
    result.endContainer = node
    result.endOffset = offset

  return

moveBoundary = (textRange, atStart, node, offset) ->
  # Find the normalized node and parent of our anchor.
  textOffset = 0
  anchorNode = (if dom.isText(node) then node else node.childNodes[offset])
  anchorParent = (if dom.isText(node) then node.parentNode else node)
  
  # Visible data nodes need an offset parameter.
  textOffset = offset  if dom.isText(node)
  
  # We create another dummy anchor element, insert it at the anchor,
  # and create a text range to select the contents of that node.
  # Then we remove the dummy.
  cursorNode = global.document.createElement("a")
  anchorParent.insertBefore cursorNode, anchorNode or null
  cursor = global.document.body.createTextRange()
  cursor.moveToElementText cursorNode
  cursorNode.parentNode.removeChild cursorNode
  
  # Update the passed-in range to this cursor.
  textRange.setEndPoint ((if atStart then "StartToStart" else "EndToEnd")), cursor
  textRange[(if atStart then "moveStart" else "moveEnd")] "character", textOffset
  return

module.exports =
  get: ->
    global.focus()
    if (range = global.document.selection.createRange()) and range.parentElement().document is global.document
      result = {}
      getBoundary range, true, result
      getBoundary range, false, result
      result

  set: (anchor, anchorOffset, focus=anchor, focusOffset=anchorOffset) ->
    range = global.document.body.createTextRange()
    moveBoundary range, false, focus, focusOffset
    moveBoundary range, true, anchor, anchorOffset
    range.select()
    return

  'clear': ->
    global.document.selection.empty()
