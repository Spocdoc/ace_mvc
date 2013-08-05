#
# derived from selection.js Copyright (c) 2011-12 Tim Cameron Ryan. MIT licensed.
#

module.exports = dom =
  'isPreceding': (n1, n2) ->
    n2.compareDocumentPosition(n1) & 0x02

  'contains': (n1, n2) ->
    if n1.compareDocumentPosition?
      n1.compareDocumentPosition(n2) & 16
    else
      n1.contains n2

  'isCursorPreceding': (n1, o1, n2, o2) ->
    return o1 <= o2  if n1 is n2
    return dom.isPreceding(n1, n2)  if dom.isText(n1) and dom.isText(n2)
    return not dom.isCursorPreceding(n2, o2, n1, o1)  if dom.isText(n1) and not dom.isText(n2)
    return dom.isPreceding(n1, n2)  unless dom.contains(n1, n2)
    return false  if n1.childNodes.length <= o1
    return 0 <= o2  if n1.childNodes[o1] is n2
    dom.isPreceding n1.childNodes[o1], n2

  'isText': (d) ->
    d?.nodeType is 3

  'getChildIndex': (e) ->
    k = 0
    k++ while e = e.previousSibling
    k

