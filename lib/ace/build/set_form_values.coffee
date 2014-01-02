_ = require 'lodash-fork'

module.exports = ($container, req) ->

  if req.body
    for k,v of req.body when ($elem = $container.find "[name=#{_.quote k}]") and $elem.length
      switch $elem.name()
        when 'INPUT'
          if $elem.length > 1
            continue unless ($elem = $elem.filter("[value=#{_.quote v}]")) and $elem.length is 1

          $elem.val v

          event =
            stopPropagation: ->
            preventDefault: ->
            target: $elem[0]

          $elem.emit 'input', event
          $elem.emit 'keyup', event
          $elem.emit 'change', event

  if req.files
    for k,v of req.files when ($elem = $container.find "[name=#{_.quote k}][type='file']") and $elem.length
      $elem[0].files = v

      event =
        stopPropagation: ->
        preventDefault: ->
        target: $elem[0]

      $elem.emit 'change', event

  return

