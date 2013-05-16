Emitter = lib 'emitter'
Listener = lib 'listener'
{extend, include} = lib '../mixin'

class E
include E, Emitter

class L
include L, Listener

describe 'Listener', ->
  beforeEach ->
    @emitter = new E
    @emitter2 = new E
    @listener = new L

  describe '#listenOn', ->
    it 'should cause function to be called when target emits event', ->
      @listener.listenOn @emitter, 'event', foo = sinon.spy ->
      @emitter.emit 'event'
      expect(foo).calledOnce

    it 'should emit with the listener context', ->
      ctx = undefined
      @listener.listenOn @emitter, 'event', -> ctx = this
      @emitter.emit 'event'
      expect(ctx).eq @listener

    it 'should allow listening to multiple emitters', ->
      @listener.listenOn @emitter, 'event', foo = sinon.spy ->
      @listener.listenOn @emitter2, 'event',bar = sinon.spy ->

      @emitter.emit 'event'
      expect(foo).calledOnce
      expect(bar).not.called

      @emitter2.emit 'event'
      expect(foo).calledOnce
      expect(bar).calledOnce

    it 'should allow listening with multiple functions', ->
      @listener.listenOn @emitter, 'event', foo = sinon.spy ->
      @listener.listenOn @emitter, 'event', bar = sinon.spy ->

      @emitter.emit 'event'
      expect(foo).calledOnce
      expect(bar).calledOnce


  describe '#listenOff', ->
    it 'should allow un-listening everything', ->
      @listener.listenOn @emitter, 'event', foo = sinon.spy ->
      @listener.listenOn @emitter2, 'event',bar = sinon.spy ->

      @listener.listenOff()

      @emitter.emit 'event'
      @emitter2.emit 'event'
      expect(foo).not.called
      expect(bar).not.called

    it 'should allow un-listening a specific emitter', ->
      @listener.listenOn @emitter, 'event', foo = sinon.spy ->
      @listener.listenOn @emitter2, 'event',bar = sinon.spy ->

      @listener.listenOff @emitter

      @emitter.emit 'event'
      @emitter2.emit 'event'
      expect(foo).not.called
      expect(bar).calledOnce

    it 'should allow un-listening a specific function', ->
      foo = sinon.spy ->
      bar = sinon.spy ->
      @listener.listenOn @emitter, 'event', foo
      @listener.listenOn @emitter, 'event', bar
      @listener.listenOn @emitter2, 'event', foo
      @listener.listenOn @emitter2, 'event', bar

      @listener.listenOff null, null, foo

      @emitter.emit 'event'
      @emitter2.emit 'event'
      expect(foo).not.called
      expect(bar).calledTwice

    it 'should allow un-listening a specific event', ->
      foo = sinon.spy ->
      bar = sinon.spy ->
      baz = sinon.spy ->
      bo = sinon.spy ->
      @listener.listenOn @emitter, 'event1', foo
      @listener.listenOn @emitter, 'event2', bar
      @listener.listenOn @emitter2, 'event2', baz
      @listener.listenOn @emitter2, 'event1', bo

      @listener.listenOff null, 'event2'

      @emitter.emit 'event1'
      @emitter.emit 'event2'
      @emitter2.emit 'event1'
      @emitter2.emit 'event2'
      expect(foo).calledOnce
      expect(bar).not.called
      expect(baz).not.called
      expect(bo).calledOnce



