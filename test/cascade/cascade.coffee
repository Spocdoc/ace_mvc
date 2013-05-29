Cascade = lib 'cascade'
Outlet = lib 'outlet'
Auto = lib 'auto'

numOutflowKeys = 2

hot = ->
  `this.afn = sinon.spy(function afn() {})`
  `this.bfn = sinon.spy(function bfn() {})`
  `this.cfn = sinon.spy(function cfn() {})`
  `this.dfn = sinon.spy(function dfn() {})`
  `this.efn = sinon.spy(function efn() {})`
  `this.ffn = sinon.spy(function ffn() {})`

  @a = new Cascade @afn
  @b = new Cascade @bfn
  @c = new Cascade @cfn
  @d = new Cascade @dfn
  @e = new Cascade @efn
  @f = new Cascade @ffn

  @f.outflows.add @a
  @f.outflows.add @d
  @f.outflows.add @c
  @a.outflows.add @b
  @a.outflows.add @c
  @d.outflows.add @c
  @c.outflows.add @e

medium = ->
  `this.afn = sinon.spy(function afn() {})`
  `this.bfn = sinon.spy(function bfn() {})`
  `this.foo = sinon.spy(function foo() {})`

  @a = new Cascade @afn
  @b = new Cascade @bfn

  @a.outflows.add(@b)
  @b.outflows.add(@foo)

describe 'Cascade mild', ->
  beforeEach ->
    @a = new Cascade

  it 'should run an outflow function once', ->
    foo = sinon.spy ->
    @a.outflows.add(foo)
    @a.outflows.add(foo)
    @a.run()
    expect(foo).calledOnce

  it 'should not run removed outflows', ->
    foo = sinon.spy ->
    @a.outflows.add(foo)
    @a.outflows.remove(foo)
    @a.run()
    expect(foo).not.called

  it 'should run the included function', ->
    foo = sinon.spy ->
    @a = new Cascade(foo)
    @a.run()
    expect(foo).calledOnce

describe 'Cascade medium', ->
  beforeEach ->
    medium.call this

  it 'should run outflows in order', ->
    @a.run()

    expect(@afn).calledOnce
    expect(@bfn).calledOnce
    expect(@foo).calledOnce

    expect(@bfn).calledAfter(@afn)
    expect(@foo).calledAfter(@bfn)

  it 'should have inflows correspond to outflows', ->
    expect(@a.outflows[@b.cid]).to.exist
    expect(@b.inflows[@a.cid]).to.exist


describe 'Cascade hot', ->
  beforeEach ->
    hot.call this

  it 'should calculate all outflows', ->
    @f.run()
    expect(@afn).calledOnce
    expect(@bfn).calledOnce
    expect(@cfn).calledOnce
    expect(@dfn).calledOnce
    expect(@efn).calledOnce
    expect(@ffn).calledOnce

  it 'should have correct inflows & outflows', ->
    expect(@f.outflows[@a.cid]).to.exist
    expect(@f.outflows[@d.cid]).to.exist
    expect(@f.outflows[@c.cid]).to.exist
    expect(@a.outflows[@b.cid]).to.exist
    expect(@a.outflows[@c.cid]).to.exist
    expect(@d.outflows[@c.cid]).to.exist
    expect(@c.outflows[@e.cid]).to.exist

    expect(@a.inflows[@f.cid]).to.exist
    expect(@d.inflows[@f.cid]).to.exist
    expect(@c.inflows[@f.cid]).to.exist
    expect(@b.inflows[@a.cid]).to.exist
    expect(@c.inflows[@a.cid]).to.exist
    expect(@c.inflows[@d.cid]).to.exist
    expect(@e.inflows[@c.cid]).to.exist

    expect(Object.keys(@f.inflows).length).eq(0)
    expect(@f.outflows.length).eq(3)

    expect(Object.keys(@a.inflows).length).eq(1)
    expect(@a.outflows.length).eq(2)

    expect(Object.keys(@d.inflows).length).eq(1)
    expect(@d.outflows.length).eq(1)

    expect(Object.keys(@c.inflows).length).eq(3)
    expect(@c.outflows.length).eq(1)

    expect(Object.keys(@b.inflows).length).eq(1)
    expect(@b.outflows.length).eq(0)

    expect(Object.keys(@e.inflows).length).eq(1)
    expect(@e.outflows.length).eq(0)


  it 'should only calculate outflows when all inflows are up to date', ->
    @f.run()
    expect(@afn).calledAfter(@ffn)
    expect(@dfn).calledAfter(@ffn)
    expect(@cfn).calledAfter(@afn)
    expect(@cfn).calledAfter(@dfn)
    expect(@bfn).calledAfter(@afn)
    expect(@efn).calledAfter(@cfn)

  it 'should remove corresponding inflows when outflows are removed', ->
    @d.outflows.remove(@c)
    @f.outflows.remove(@c)

    expect(@f.outflows[@a.cid]).to.exist
    expect(@f.outflows[@d.cid]).to.exist
    expect(@f.outflows[@c.cid]).to.not.exist
    expect(@a.outflows[@b.cid]).to.exist
    expect(@a.outflows[@c.cid]).to.exist
    expect(@d.outflows[@c.cid]).to.not.exist
    expect(@c.outflows[@e.cid]).to.exist

    expect(@a.inflows[@f.cid]).to.exist
    expect(@d.inflows[@f.cid]).to.exist
    expect(@c.inflows[@f.cid]).to.not.exist
    expect(@b.inflows[@a.cid]).to.exist
    expect(@c.inflows[@a.cid]).to.exist
    expect(@c.inflows[@d.cid]).to.not.exist
    expect(@e.inflows[@c.cid]).to.exist

    # outflows always 1 greater than actual number

    expect(Object.keys(@f.inflows).length).eq(0)
    expect(@f.outflows.length).eq(2)

    expect(Object.keys(@a.inflows).length).eq(1)
    expect(@a.outflows.length).eq(2)

    expect(Object.keys(@d.inflows).length).eq(1)
    expect(@d.outflows.length).eq(0)

    expect(Object.keys(@c.inflows).length).eq(1)
    expect(@c.outflows.length).eq(1)

    expect(Object.keys(@b.inflows).length).eq(1)
    expect(@b.outflows.length).eq(0)

    expect(Object.keys(@e.inflows).length).eq(1)
    expect(@e.outflows.length).eq(0)

describe '#detach', ->
  beforeEach ->
    hot.call this
    @c.detach()

  it 'should not calculate an outflow if it has been detached', ->
    @f.run()
    expect(@afn).calledAfter(@ffn)
    expect(@bfn).calledAfter(@afn)
    expect(@dfn).calledAfter(@ffn)
    expect(@cfn).not.called
    expect(@efn).not.called

  it 'should preserve outflows for the detached cascade', ->
    @c.run()
    expect(@afn).not.called
    expect(@bfn).not.called
    expect(@dfn).not.called
    expect(@cfn).calledOnce
    expect(@efn).calledOnce
    expect(@efn).calledAfter(@cfn)

describe 'Cascade.Block mild', ->
  beforeEach ->
    medium.call this

  it 'should return a function that can be invoked repeatedly when called with `new`', ->
    f = new Cascade.Block =>
      @a.run()

    expect(@afn).not.called

    f()

    expect(@afn).calledOnce

    f()

    expect(@afn).calledTwice

  it 'should invoke immediately when called and return the function result', ->
    ret = Cascade.Block =>
      @a.run()
      42

    expect(ret).eq 42
    expect(@afn).calledOnce
    
describe 'Cascade.Block medium', ->
  beforeEach ->
    hot.call this

  it 'should call nested dependencies only once', ->
    ret = Cascade.Block =>
      @a.run()
      @d.run()
      42

    expect(ret).eq 42
    expect(@afn).calledOnce
    expect(@bfn).calledOnce
    expect(@cfn).calledOnce
    expect(@dfn).calledOnce
    expect(@efn).calledOnce

  it 'should call nested dependencies in the right order', ->
    Cascade.Block =>
      @a.run()
      @d.run()

    expect(@cfn).calledAfter(@afn)
    expect(@cfn).calledAfter(@dfn)
    expect(@bfn).calledAfter(@afn)
    expect(@efn).calledAfter(@cfn)

  it 'should cascade values only once', ->
    @modelWidth = new Outlet(1)
    @modelHeight = new Outlet(1)
    
    foo = sinon.spy ->

    a = new Auto =>
      @modelWidth.get()
      @modelHeight.get()
      foo()

    expect(foo).calledOnce

    Cascade.Block =>
      @modelWidth.set(2)
      @modelHeight.set(3)

    expect(foo).calledTwice

describe 'Cascade events', ->
  # it 'should emit a \'pendingTrue\' event when pending is changed', ->
  #   @a = new Cascade foo = sinon.spy ->
  #   @args = []
  #   @event = sinon.spy => @args = arguments
  #   Cascade.Block =>
  #     args = undefined
  #     @a.on 'pendingTrue', @event
  #     @a.run()
  #     expect(@event).calledOnce
  #     expect(@args.length).eq 1
  #     expect(@args[0]).eq @a
  #     expect(foo).not.called
  #   expect(foo).calledOnce
  #   expect(@event).calledOnce


describe 'Cascade.Outflows', ->
  describe '#detach and #attach', ->
    it 'when its outflows are detached, it doesn\'t update them', ->
      x = new Outlet 1
      a = new Auto foo = sinon.spy ->
        y = x.get() * 2
      expect(foo).calledOnce
      outflows = x.outflows.detach()
      x.set(2)
      expect(foo).calledOnce
 
#     it 'when its outflows are reattached, it immediately updates only the new outflows', ->
#       x = new Outlet 1
#       a = new Auto foo = sinon.spy -> x.get() * 2
#       expect(foo).calledOnce
#       outflows = x.outflows.detach()
#       b = new Auto bar = sinon.spy -> x.get() * 3
#       x.set(2)
#       expect(foo).calledOnce
#       expect(bar).calledTwice
#       x.outflows.attach outflows
#       expect(foo).calledTwice
#       expect(bar).calledTwice

    it 'when its outflows are re-attached and it has changed, it updates them', ->
      x = new Outlet 1
      a = new Auto foo = sinon.spy -> x.get() * 2
      expect(foo).calledOnce
      outflows = x.outflows.detach()
      b = new Auto bar = sinon.spy -> x.get() * 3
      x.set(2)
      expect(foo).calledOnce
      expect(bar).calledTwice
      x.outflows.attach outflows
      # expect(foo).calledTwice
      # expect(bar).calledTwice
      x.set(3)
      expect(foo).calledTwice
      expect(bar).calledThrice

    it 'when its outflows are detached, the previous outflows have the corresponding inflow removed', ->
      x = new Outlet 1
      a = new Outlet (foo = sinon.spy ->
        y = x.get() * 2),auto:true
      expect(Object.keys(a.inflows).length).eq 1
      outflows = x.outflows.detach()
      expect(Object.keys(a.inflows).length).eq 0

describe 'Cascade async', ->
  it 'only calls outflows when the function is called', (fin) ->
    a = new Cascade
    b = new Cascade

    a.outflows.add b

    result = 0

    b.func = ->
      expect(result).eq 42
      fin()

    a.func = (done) ->
      setTimeout (->
        result = 42
        done()), 0

    a.run()

  it 'keeps outflows pending that are dependent on other synchronous inflows', (fin) ->

    afn = sinon.spy ->
    bfn = sinon.spy ->

    d = new Cascade
    a = new Cascade (done) ->
      setTimeout (->
        afn()
        done()
      ), 0
    b = new Cascade ->
      bfn()
    c = new Cascade ->
      expect(afn).calledOnce
      expect(bfn).calledOnce
      expect(afn).calledAfter(bfn)
      fin()

    d.outflows.add a
    d.outflows.add b
    a.outflows.add c
    b.outflows.add c

    d.run()

  it 'does not call the outflows if there are more recent calls', (fin) ->
    timeout = (fn) -> setTimeout(fn, 0)

    a2 = sinon.spy ->

    a1 = sinon.spy ->
      expect(a2).calledOnce
      timeout ->
        timeout ->
          expect(bfn).calledOnce # i.e., not twice
          fin()

    a = new Cascade
    b = new Cascade bfn = sinon.spy ->
      expect(a1).not.called
      expect(a2).calledOnce

    a.outflows.add b

    a.func = (done) ->
      timeout ->
        timeout ->
          timeout ->
            a1()
            done()

    a.run()

    a.func = (done) ->
      timeout ->
        a2()
        done()

    a.run()


