Outlet = require '../outlet'
Cascade = require '../cascade'

describe 'Outlet mild', ->
  beforeEach ->
    @a = new Outlet(1)

  it 'should set the initial value to constructor arg', ->
    expect(@a.get()).eq 1

  it 'should set the value when changed and return it in setter', ->
    expect(@a.set(2)).eq 2
    expect(@a.get()).eq 2

  it 'should cascade when set', ->
    `this.bfn = sinon.spy(function bfn() {})`
    @b = new Cascade @bfn

    @a.outflows.add @b
    @a.set 2

    expect(@bfn).calledOnce

  it 'should not cascade when set to the same value', ->
    `this.bfn = sinon.spy(function bfn() {})`
    @b = new Cascade @bfn

    @a.outflows.add @b
    expect(@a.set 1).eq 1
    expect(@a.get()).eq 1
    expect(@bfn).not.called

describe 'Outlet medium', ->
  beforeEach ->
    @a = new Outlet(1)
    @b = new Outlet(2)
    @b.set(@a)

  it 'should cascade a value immediately when set', ->
    expect(@b.get()).eq 1

  it 'should cascade a value when inflow\'s value is set', ->
    @a.set(3)
    expect(@b.get()).eq 3

describe 'Outlet hot', ->
  beforeEach ->
    @a = new Outlet(1)
    @b = new Outlet(2)

    callCounts = {}
    @callCounts = callCounts

    orig = Cascade.prototype._calculate
    Cascade.prototype._calculate = ->
      callCounts[this.cid] ?= 0
      ++callCounts[this.cid]
      orig.apply(this, arguments)

    @b.set(@a)

  it 'when the inflow outlet is changed to another outlet, it should not recalculate when the original inflow outlet changes', ->
    expect(@callCounts[@b.cid]).eq 1
    @a1 = new Outlet(3)
    @b.set(@a1)
    expect(@b.get()).eq(@a1.get())
    expect(@callCounts[@b.cid]).eq 2
    @a.set(999)
    expect(@callCounts[@b.cid]).eq 2

  it 'should re-fetch a function when recalculated as part of a cascade', ->
    func = sinon.spy ->
      return 42
    expect(@callCounts[@a.cid]).not.exist
    @a.set(func)
    expect(@callCounts[@b.cid]).eq 2
    expect(@callCounts[@a.cid]).eq 1
    expect(func).calledOnce

    @c = new Cascade
    @c.outflows.add(@a)
    @c.run()
    expect(@callCounts[@b.cid]).eq 3
    expect(@callCounts[@a.cid]).eq 2
    expect(func).calledTwice

  describe '#detach', ->
    beforeEach ->
      @b.detach()

    it 'should preserve its value when detached', ->
      expect(@b.get()).eq 1
      expect(@callCounts[@b.cid]).eq 1


    it 'should not re-fetch when the previous inflow is updated', ->
      @a.set(42)
      expect(@b.get()).eq 1
      expect(@callCounts[@b.cid]).eq 1

    it 'should not re-fetch any values from the previous inflow when run', ->
      @a.set(42)
      @b.run()
      expect(@callCounts[@b.cid]).eq 2
      expect(@b.get()).eq 1

    it 'should have the correct value when a new inflow is assigned', ->
      func = sinon.spy ->
        return 99
      @b.set(func)
      expect(@b.get()).eq 99
      expect(@callCounts[@b.cid]).eq 2
      expect(func).calledOnce



