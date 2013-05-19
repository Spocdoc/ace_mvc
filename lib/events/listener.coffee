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

  listenOff: (emitter, event, fn) ->
    if not emitter?
      for cid, [emitter] of @_listener
        @listenOff(emitter, event, fn)
      delete @_listener[emitter] unless event? or fn?
      return

    if not event?
      [emitter,events] = @_listener[emitter.cid]
      for event of events
        @listenOff(emitter, event, fn)
      return

    emitter.off(event,fn,this)
    delete @_listener[emitter.cid][1][event] unless fn?
    return

