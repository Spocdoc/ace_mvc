api = require './api'

ControllerBase = require './mvc/controller_base'
View = require './mvc/view'
Controller = require './mvc/controller'
Ace = require './ace'

api View.prototype,
  newTemplate: 'newTemplate'
  appendTo: 'appendTo'
  prependTo: 'prependTo'
  insertBefore: 'insertBefore'
  insertAfter: 'insertAfter'
  remove: 'remove'

api Controller.prototype,
  newView: 'newView'
  newModel: 'newModel'
  appendTo: 'appendTo'
  prependTo: 'prependTo'
  insertBefore: 'insertBefore'
  insertAfter: 'insertAfter'
  remove: 'remove'

api Ace,
  newClient: 'newClient'

api Ace.View.prototype,
  newOutletMethod: 'newOutletMethod'
  newStatelet: 'newStatelet'
  local: 'local'
  from: 'from'
  to: 'to'
  sliding: 'sliding'
  diff: 'diff'

api Ace.Controller.prototype,
  newController: 'newController'
  newOutletMethod: 'newOutletMethod'
  newView: 'newView'
  newModel: 'newModel'
  local: 'local'
  from: 'from'
  to: 'to'
  sliding: 'sliding'
  diff: 'diff'

api Ace.Model.prototype,
  onbuilt: 'onbuilt'

