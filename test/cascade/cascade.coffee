Cascade = lib 'cascade'
Outlet = lib 'outlet'
Autorun = lib 'autorun'

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

    # outflows always 1 greater than actual number

    expect(Object.keys(@f.inflows).length).eq(0)
    expect(Object.keys(@f.outflows).length-1).eq(3)

    expect(Object.keys(@a.inflows).length).eq(1)
    expect(Object.keys(@a.outflows).length-1).eq(2)

    expect(Object.keys(@d.inflows).length).eq(1)
    expect(Object.keys(@d.outflows).length-1).eq(1)

    expect(Object.keys(@c.inflows).length).eq(3)
    expect(Object.keys(@c.outflows).length-1).eq(1)

    expect(Object.keys(@b.inflows).length).eq(1)
    expect(Object.keys(@b.outflows).length-1).eq(0)

    expect(Object.keys(@e.inflows).length).eq(1)
    expect(Object.keys(@e.outflows).length-1).eq(0)


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
    expect(Object.keys(@f.outflows).length-1).eq(2)

    expect(Object.keys(@a.inflows).length).eq(1)
    expect(Object.keys(@a.outflows).length-1).eq(2)

    expect(Object.keys(@d.inflows).length).eq(1)
    expect(Object.keys(@d.outflows).length-1).eq(0)

    expect(Object.keys(@c.inflows).length).eq(1)
    expect(Object.keys(@c.outflows).length-1).eq(1)

    expect(Object.keys(@b.inflows).length).eq(1)
    expect(Object.keys(@b.outflows).length-1).eq(0)

    expect(Object.keys(@e.inflows).length).eq(1)
    expect(Object.keys(@e.outflows).length-1).eq(0)

  describe '#detach', ->
    beforeEach ->
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

    a = new Autorun =>
      @modelWidth.get()
      @modelHeight.get()
      foo()

    expect(foo).calledOnce

    Cascade.Block =>
      @modelWidth.set(2)
      @modelHeight.set(3)

    expect(foo).calledTwice


