count = 0
uniqueId = ->
  count = if count+1 == count then 0 else count+1
  "#{count}-Listener"

module.exports = Listener =
  listenOn: (emitter, event, fn) ->
    obj = [emitter, {}]
    obj[1][event] = 1
    (@_listener ?= {})[emitter.cid ?= uniqueId()] = obj
    emitter.on event, fn, this

  isListening: (emitter, event) ->
    unless event?
      @_listener?[emitter.cid]?
    else
      @_listener?[emitter.cid]?[1][event]

  listenOff: (emitter, event, fn) ->
    return unless @_listener

    if not emitter?
      for cid, [emitter] of @_listener
        @listenOff(emitter, event, fn)
      delete @_listener unless event? or fn?
      return

    return unless emitter.cid?

    if not event?
      [emitter,events] = @_listener[emitter.cid]
      for event of events
        @listenOff(emitter, event, fn)
      return

    emitter.off(event,fn,this)
    delete @_listener[emitter.cid][1][event] unless fn?
    return

