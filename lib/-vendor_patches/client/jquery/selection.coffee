if (rangy = global.rangy || global.document) and typeof rangy.getSelection is 'function'

  # or can pass two points or a single range
  $['selection'] = (start, end) ->
    return unless sel = rangy.getSelection()

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
        range = rangy.createRange()
        range.setStart start['container'], start['offset']
        range.setEnd end['container'], end['offset']
        sel.removeAllRanges()
        sel.addRange range
      catch _error
      return

  $['selection']['clear'] = ->
    try
      rangy.getSelection()?.removeAllRanges()
    catch _error
    return

  $['selection']['isCollapsed'] = ->
    rangy.getSelection()?.isCollapsed

