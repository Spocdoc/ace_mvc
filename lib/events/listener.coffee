count = 0
uniqueId = ->
  "#{++count}-Listener"

module.exports = Listener =
  listenOn: (emitter, event, fn) ->
    (@_listener ?= {})[emitter.cid ?= uniqueId()] = emitter
    emitter.on event, fn, this

  listenOff: (emitter, event, fn) ->
    if not emitter?
      emitter.off event, fn, this for cid,emitter of @_listener
      delete @_listener
    else
      emitter.off event, fn, this
    return

