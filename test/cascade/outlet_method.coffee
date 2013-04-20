OutletMethod = lib 'outlet_method'
Outlet = lib 'outlet'
Cascade = lib 'cascade'

addCallCounts = ->
  callCounts = {}
  @callCounts = callCounts

  orig = Cascade.prototype._calculate
  Cascade.prototype._calculate = ->
    callCounts[this.cid] ?= 0
    ++callCounts[this.cid]
    orig.apply(this, arguments)

describe 'OutletMethod mild', ->
  beforeEach ->
    addCallCounts.call this

    callCounts = @callCounts

    @x = new Outlet(1)
    # can't uses sinon.spy because it doesn't preserve arg names
    @foo = (x) ->
      callCounts[@cid] ?= 0
      ++callCounts[@cid]
      2*x
    @m = new OutletMethod @foo,
      x: @x

  it 'should find inflows based on argument names', ->
    expect(@m.inflows[@x.cid]).to.exist

    expect(Object.keys(@m.inflows).length).eq 1
    expect(Object.keys(@m.outflows).length-1).eq 0

    expect(@x.outflows[@m.cid]).to.exist
    expect(Object.keys(@x.inflows).length).eq 0
    expect(Object.keys(@x.outflows).length-1).eq 1

    expect(@m.get()).eq (2*@x.get())
    expect(@callCounts[@foo.cid]).eq 1
    expect(@callCounts[@x.cid]).not.exist
    expect(@callCounts[@m.cid]).eq 1

  it 'should recalculate when an inflow changes', ->
    @x.set(42)

    expect(@callCounts[@x.cid]).not.exist
    expect(@callCounts[@m.cid]).eq 2
    expect(@callCounts[@foo.cid]).eq 2
    expect(@m.get()).eq 84

  it 'should not recalculate when detached and prior inflow changes', ->
    @m.detach()
    @x.set(42)
    expect(@callCounts[@x.cid]).not.exist
    expect(@callCounts[@m.cid]).eq 1
    expect(@callCounts[@foo.cid]).eq 1
    expect(@m.get()).eq 2

  it 'should recalculate when rebound', ->
    @y = new Outlet(2)
    @m.rebind x: @y

    expect(@callCounts[@x.cid]).not.exist
    expect(@callCounts[@m.cid]).eq 2
    expect(@callCounts[@foo.cid]).eq 2
    expect(@m.get()).eq 4

  it 'should not recalculate when rebound and prior inflow changes', ->
    @y = new Outlet(2)
    @m.rebind x: @y

    expectations = =>
      expect(@callCounts[@x.cid]).not.exist
      expect(@callCounts[@m.cid]).eq 2
      expect(@callCounts[@foo.cid]).eq 2
      expect(@m.get()).eq 4

    expectations()
    @x.set(42)
    expectations()

describe 'OutletMethod medium', ->
  beforeEach ->
    addCallCounts.call this
    callCounts = @callCounts

    @x = new Outlet(1)
    @y = new Outlet(2)

    # can't uses sinon.spy because it doesn't preserve arg names
    @foo = (x,y) ->
      callCounts[@cid] ?= 0
      ++callCounts[@cid]
      2*x + 3*y

    @m = new OutletMethod @foo,
      x: @x
      y: @y

  it 'should find inflows based on argument names', ->
    expect(@m.inflows[@x.cid]).to.exist
    expect(@m.inflows[@y.cid]).to.exist

    expect(Object.keys(@m.inflows).length).eq 2
    expect(Object.keys(@m.outflows).length-1).eq 0

    expect(@x.outflows[@m.cid]).to.exist
    expect(Object.keys(@x.inflows).length).eq 0
    expect(Object.keys(@x.outflows).length-1).eq 1

    expect(@y.outflows[@m.cid]).to.exist
    expect(Object.keys(@y.inflows).length).eq 0
    expect(Object.keys(@y.outflows).length-1).eq 1

    expect(@m.get()).eq (2*@x.get() + 3*@y.get())
    expect(@callCounts[@foo.cid]).eq 1
    expect(@callCounts[@x.cid]).not.exist
    expect(@callCounts[@y.cid]).not.exist
    expect(@callCounts[@m.cid]).eq 1

  it 'should recalculate when any of the inputs change', ->
    @x.set(42)

    expect(@callCounts[@foo.cid]).eq 2
    expect(@callCounts[@x.cid]).not.exist
    expect(@callCounts[@y.cid]).not.exist
    expect(@callCounts[@m.cid]).eq 2

  it 'should have the right value when rebound', ->
    @m.rebind
      x: @y
      y: @x

    expect(@callCounts[@foo.cid]).eq 2
    expect(@callCounts[@m.cid]).eq 2
    expect(@callCounts[@x.cid]).not.exist
    expect(@callCounts[@y.cid]).not.exist
    expect(@m.get()).eq 7


