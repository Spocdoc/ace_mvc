Emitter = require '../events/emitter'
{include} = require '../mixin'
makeId = require '../id'

module.exports = class FocusGroup
  include this, Emitter

  constructor: ->
    @['add'] $elem for $elem in arguments
    @id = makeId()

  'focus': ($elem) -> @focused = $elem

  'add': ($elem, focused) ->
    $elem.on "mousedown.#{@id}", =>
      focused = @focused
      @focused = $elem
      @emit 'focus' unless focused
      return

    $elem.on "blur.#{@id}", =>
      if $elem is @focused
        @focused = null
        @emit 'blur'
      return

    @focused = $elem if focused
    return

  'remove': ($elem) ->
    $elem.off "mousedown.#{@id} blur.#{@id} focus.#{@id}"
    return




