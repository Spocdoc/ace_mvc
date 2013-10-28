module.exports = ($container, obj) ->
  for k,v of obj when $elem = $container.find("##{k}")
    switch $elem.name()
      when 'INPUT'
        $elem.val v
        event =
          stopPropagation: ->
          preventDefault: ->
          target: $elem[0]
        $elem.emit 'input', event
        $elem.emit 'keyup', event
        $elem.emit 'change', event

  return

