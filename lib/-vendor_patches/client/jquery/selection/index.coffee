if global.getSelection

  # or can pass two points or a single range
  $['selection'] = (start, end) ->
    return unless sel = global.getSelection()

    unless start?
      if range = sel and sel.rangeCount and sel.getRangeAt(0)
        return {
          'start':
            'container': range.startContainer
            'offset': range.startOffset
          'end':
            'container': range.endContainer
            'offset': range.endOffset
        }
    else
      if start['start']
        end = start['end']
        start = start['start']

      try
        end ||= start
        range = global.document.createRange()
        range.setStart start['container'], start['offset']
        range.setEnd end['container'], end['offset']
        sel.removeAllRanges()
        sel.addRange range
      catch _error
      return

  $['selection']['clear'] = ->
    try
      global.getSelection()?.removeAllRanges()
    catch _error
    return

  $['selection']['isCollapsed'] = ->
    global.getSelection()?.isCollapsed


else unless global.document?.selection
  $['selection'] = ->
  $['selection']['clear'] = ->
else
  $['selection'] = require './ie'

