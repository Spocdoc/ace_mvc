Emitter = lib 'emitter'
{extend, include} = lib '../mixin/mixin'

class A
include A, Emitter

describe 'Emitter', ->
  describe '#emit', ->
    it 'should call the listener functions', ->
      @a = new A
      @a.on 'foo', foo = sinon.spy ->
      @a.emit 'foo'
      expect(foo).calledOnce
      @a.emit 'foo'
      expect(foo).calledTwice

    it 'should invoke with expected context', ->
      @a = new A
      fcx = undefined
      bcx = undefined
      foo = sinon.spy -> fcx = this
      bar = sinon.spy -> bcx = this
      @a.on 'foo', foo, one={}
      @a.on 'foo', bar, two={}
      @a.on 'bar', foo, three={}
      @a.on 'bar', bar, four={}

      @a.emit 'foo'
      expect(fcx).eq one
      expect(bcx).eq two

      @a.emit 'bar'
      expect(fcx).eq three
      expect(bcx).eq four

    it 'should pass arguments', ->
      @a = new A
      fargs = []
      bargs = []
      foo = sinon.spy -> fargs = arguments
      bar = sinon.spy -> bargs = arguments
      @a.on 'foo', foo, one={}
      @a.on 'foo', bar, two={}
      @a.on 'bar', foo, three={}
      @a.on 'bar', bar, four={}

      @a.emit 'foo', 1, 2, 3
      expect(fargs[j]).eq i for i,j in [1,2,3]
      expect(bargs[j]).eq i for i,j in [1,2,3]

      @a.emit 'bar', 4, 5, 6
      expect(fargs[j]).eq i for i,j in [4,5,6]
      expect(bargs[j]).eq i for i,j in [4,5,6]

  describe '#off', ->
    it 'should not call listener functions once removed', ->
      @a = new A
      @a.on 'foo', foo = sinon.spy ->
      @a.off 'foo'
      @a.emit 'foo'
      expect(foo).not.called

    it 'should remove only specific functions if passed', ->
      @a = new A
      @a.on 'foo', foo = sinon.spy ->
      @a.on 'foo', bar = sinon.spy ->
      @a.on 'baz', bar = sinon.spy ->
      @a.off 'foo', bar
      @a.emit 'foo'
      expect(foo).calledOnce
      expect(bar).not.called
      @a.emit 'baz'
      expect(foo).calledOnce
      expect(bar).calledOnce

    it 'should remove by context', ->
      @a = new A
      foo = sinon.spy ->
      bar = sinon.spy ->
      @a.on 'foo', foo, 1
      @a.on 'foo', bar, 2
      @a.on 'bar', foo, 2
      @a.on 'bar', bar, 1
      @a.off null, null, 2
      @a.emit 'foo'
      expect(foo).calledOnce
      @a.emit 'bar'
      expect(bar).calledOnce

    it 'should remove if given context and function', ->
      @a = new A
      foo = sinon.spy ->
      bar = sinon.spy ->
      @a.on 'foo', foo, 1
      @a.on 'foo', bar, 2
      @a.on 'bar', foo, 2
      @a.on 'bar', bar, 1
      @a.off null, foo, 2
      @a.emit 'bar'
      expect(foo).not.called
      expect(bar).calledOnce
      @a.emit 'foo'
      expect(foo).calledOnce
      expect(bar).calledTwice



