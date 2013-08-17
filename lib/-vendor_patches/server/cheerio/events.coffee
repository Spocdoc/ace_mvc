{extend} = require '../../../utils/mixin'
Emitter = require '../../../utils/events/emitter'
emptyFn = -> this

HANDLED_EVENTS = [
  'blur'
  'change'
  'focus'
  'keydown'
  'keyup'
  'select'
]

UNHANDLED_EVENTS = [
  "click"
  "dblclick"
  "error"
  "focusin"
  "focusout"
  "focusout"
  "hover"
  "keypress"
  "load"
  "mousedown"
  "mouseenter"
  "mouseleave"
  "mousemove"
  "mouseout"
  "mouseover"
  "mouseup"
  "ready"
  "resize"
  "scroll"
  "submit"
  "toggle"
  "unload"
]

$prototype = global.$('').constructor.prototype

for event in UNHANDLED_EVENTS
  $prototype[event] = emptyFn

for event in HANDLED_EVENTS
  $prototype[event] = (arg) -> @on event, arg

extend $prototype,

  select: (arg) ->
    if arg
      @on 'select', arg
    else
      @attr 'autofocus', true
    this

  focus: (arg) ->
    if arg
      @on 'focus', arg
    else
      @attr 'autofocus', true
    this

  emit: ->
    for elem in this
      Emitter.emit.apply elem, arguments
    this

  on: (desc, fn) ->
    for elem in this
      for event in desc.split ' '
        [event,ctx] = event.split '.'
        Emitter.on.call elem, event, fn, ctx
    this

  off: (desc, fn) ->
    for elem in this
      for event in desc.split ' '
        [event,ctx] = event.split '.'
        Emitter.off.call elem, event, fn, ctx
    this

