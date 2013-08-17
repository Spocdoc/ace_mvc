{extend} = require '../../../utils/mixin'

$prototype = global.$('').constructor.prototype

global.$.fn =
  extend: (obj) ->
    extend $prototype, obj
    return
