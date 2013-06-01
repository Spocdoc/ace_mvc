api = require './api'

ControllerBase = require './mvc/controller_base'
View = require './mvc/view'
Controller = require './mvc/controller'
Ace = require './ace'

api ControllerBase.prototype,
  newOutlet: 'newOutlet'
  newOutletMethod: 'newOutletMethod'

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
  newFromOutlet: 'newFromOutlet'
  newOutlet: 'newOutlet'
  newOutletMethod: 'newOutletMethod'
  newSlidingOutlet: 'newSlidingOutlet'
  newStatelet: 'newStatelet'
  local: 'local'
  from: 'from'
  to: 'to'
  diff: 'diff'

api Ace.Controller.prototype,
  newController: 'newController'
  newFromOutlet: 'newFromOutlet'
  newOutlet: 'newOutlet'
  newOutletMethod: 'newOutletMethod'
  newSlidingOutlet: 'newSlidingOutlet'
  newView: 'newView'
  newModel: 'newModel'
  local: 'local'
  from: 'from'
  to: 'to'
  diff: 'diff'

