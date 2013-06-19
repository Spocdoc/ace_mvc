api = (selves, syms) ->
  for self in selves
    self[name] = v for mangle,name of syms when (v = self[mangle])?
  return

module.exports = undefined

ControllerBase = require './mvc/controller_base'
View = require './mvc/view'
Controller = require './mvc/controller'
Ace = require './ace'

api [View.prototype, Controller.prototype],
  appendTo: 'appendTo'
  prependTo: 'prependTo'
  insertBefore: 'insertBefore'
  insertAfter: 'insertAfter'
  remove: 'remove'

api [Ace],
  newClient: 'newClient'
  findModel: 'findModel'

api [Ace.View.prototype, Ace.Controller.prototype, Ace.Model.prototype, Ace.RouteContext.prototype],
  newTemplate: 'newTemplate'
  newOutletMethod: 'newOutletMethod'
  newStatelet: 'newStatelet'
  newController: 'newController'
  newOutletMethod: 'newOutletMethod'
  newView: 'newView'
  newModel: 'newModel'
  local: 'local'
  from: 'from'
  to: 'to'
  sliding: 'sliding'
  diff: 'diff'
  newOutlet: 'newOutlet'
  newAuto: 'newAuto'
  onbuilt: 'onbuilt'
