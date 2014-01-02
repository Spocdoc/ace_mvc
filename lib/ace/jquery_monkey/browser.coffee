Template = require '../../mvc/template'



$['fn']['addClass!'] = addClassOrig = $['fn']['addClass']
$['fn']['addClass'] = ->
  return if @['template'] and Template.bootRoot
  addClassOrig.apply this, arguments


$['fn']['removeClass!'] = removeClassOrig = $['fn']['removeClass']
$['fn']['removeClass'] = ->
  return if @['template'] and Template.bootRoot
  removeClassOrig.apply this, arguments



toggleClassOrig = $['fn']['toggleClass']
$['fn']['toggleClass'] = ->
  return if @['template'] and Template.bootRoot
  toggleClassOrig.apply this, arguments

$['fn']['toggleClass!'] = (className, arg) ->
  return toggleClassOrig() unless arg?
  if arg
    addClassOrig.call this, className, arg
  else
    removeClassOrig.call this, className, arg
