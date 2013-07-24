Controller = require '../mvc/controller'

class Ace
  constructor: (@globals, @router) ->
    @_name = 'ace'
    @vars = @router.vars
    (@controller = new Controller['body'](this))['appendTo'] globals.Template.$container

module.exports = Ace
