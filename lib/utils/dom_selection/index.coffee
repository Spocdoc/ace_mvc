module.exports =
  get: ->
    (sel = global.getSelection()) and sel.rangeCount and sel.getRangeAt(0)

  set: (anchor, anchorOffset, focus, focusOffset) ->
    return unless sel = global.getSelection()
    if sel.collapse && sel.extend
      sel.collapse anchor, anchorOffset
      sel.extend focus, focusOffset if focus
    else
      range = global.document.createRange()
      range.setStart anchor, anchorOffset
      range.setEnd focus, focusOffset
      try
        sel.removeAllRanges()
      catch _error
      sel.addRange range
    return

  'clear': ->
    try
      global.getSelection()?.removeAllRanges()
    catch _error
    return

# IE -- the entire raison d'etre of this abstraction
if !global.getSelection
  unless global.document.selection
    emptyFn = ->
    module.exports =
      get: emptyFn
      set: emptyFn
      'clear': emptyFn

  else
    module.exports = require './selection_ie'
