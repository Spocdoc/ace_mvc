OutletMethod = lib 'outlet_method'
Outlet = lib 'outlet'
Cascade = lib 'cascade'
Auto = lib 'auto'

numOutflowKeys = 2


addCallCounts = ->
  callCounts = {}
  @callCounts = callCounts

  orig = Cascade.prototype._run
  Cascade.prototype._run = ->
    return unless this.pending
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
    obj = x: @x
    @m = new OutletMethod @foo, obj, names: Object.keys(obj)

  it 'should find inflows based on argument names', ->
    expect(@m.inflows[@x.cid]).to.exist

    expect(Object.keys(@m.inflows).length).eq 1
    expect(@m.outflows.array.length).eq 0

    expect(@x.outflows[@m.cid]).to.exist
    expect(Object.keys(@x.inflows).length).eq 0
    expect(@x.outflows.array.length).eq 1

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

    obj =
      x: @x
      y: @y
    @m = new OutletMethod @foo, obj, names: Object.keys(obj)

  it 'should find inflows based on argument names', ->
    expect(@m.inflows[@x.cid]).to.exist
    expect(@m.inflows[@y.cid]).to.exist

    expect(Object.keys(@m.inflows).length).eq 2
    expect(@m.outflows.array.length).eq 0

    expect(@x.outflows[@m.cid]).to.exist
    expect(Object.keys(@x.inflows).length).eq 0
    expect(@x.outflows.array.length).eq 1

    expect(@y.outflows[@m.cid]).to.exist
    expect(Object.keys(@y.inflows).length).eq 0
    expect(@y.outflows.array.length).eq 1

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

  it 'should not recalculate when released and prior inputs change', ->
    @m.detach()
    @x.set(42)
    @y.set(43)

    expect(@m.get()).eq 8
    expect(@callCounts[@m.cid]).eq 1

  # decided against this
  # it 'should not recalculate when rebound to outlets with the same value', ->
  #   @m.detach()
  #   expect(@m.get()).eq 8
  #   expect(@callCounts[@foo.cid]).eq 1
  #   x1 = new Outlet(1)
  #   y1 = new Outlet(2)
  #   @m.rebind x: x1, y: y1
  #   expect(@m.get()).eq 8
  #   expect(@callCounts[@foo.cid]).eq 1

  it 'should recalculate when rebound to outlets that have changed', ->
    @m.detach()
    @x.set(2)
    expect(@m.get()).eq 8
    expect(@callCounts[@m.cid]).eq 1
    @m.rebind x: @x, y: @y
    expect(@m.get()).eq 10
    expect(@callCounts[@m.cid]).eq 2

describe 'OutletMethod #restoreValue', ->
  it 'should not call method when restored and rebound to the same inflow values', ->
    x = new Outlet 2
    y = new Outlet 3

    obj = x: x, y: y
    mServer = new OutletMethod ((x,y) -> x*y), undefined, names: Object.keys(obj)
    mServer.rebind obj
    expect(mServer.get()).eq 6

    # now on the client, restore the value...

    foo = sinon.spy (x,y) -> x*y
    obj = x: x, y: y
    m = new OutletMethod ((x,y) -> foo(x,y)), obj,
      silent: true
      value: 6
      names: Object.keys(obj)

    expect(foo).not.called
    expect(m.get()).eq 6

    mOutflow = new Auto (bar = sinon.spy -> m.get())
    expect(m.outflows[mOutflow.cid]).exist
    expect(bar).calledOnce
    expect(mOutflow.get()).eq 6

    # # decided against
    # # also, shouldn't call when rebound

    # x1 = new Outlet 2
    # y1 = new Outlet 3

    # m.rebind x: x1, y: y1
    # expect(foo).not.called
    # expect(bar).calledOnce

describe 'OutletMethod with object inputs', ->
  it 'should recalculate when an input is an object', ->
    arr = [1,2,3]
    a = new Outlet arr
    foo = sinon.spy ->
    bar = sinon.spy ->
    method = (a) ->
      foo()
      a[0]
    obj = a:a
    m = new OutletMethod method, obj, names: Object.keys(obj)
    b = new Outlet ->
      bar()
      m.get()

    expect(foo).calledOnce
    expect(bar).calledOnce
    expect(b.get()).eq 1
    arr.push(4)
    expect(foo).calledOnce
    expect(bar).calledOnce
    expect(b.get()).eq 1

    # TODO
    # a.changed()
    # expect(foo).calledTwice
    # expect(bar).calledOnce
    # expect(b.get()).eq 1

describe 'OutletMethod setting other outlets', ->
  it 'should not add those outlets as inflows', ->
    foo = sinon.spy ->
    i = 0
    a = new Outlet
    om = new OutletMethod (->
      foo()
      a.set(++i)), {}

    expect(foo).calledOnce
    a.set(-1)
    expect(foo).calledOnce

describe 'OutletMethod', ->
  it 'should run in a cascade block', ->
    count = 0

    b = new Outlet
    c = new Outlet
    d = new Outlet -> ++count

    b.outflows.add d
    c.outflows.add d

    expect(count).eq 1

    num = 42

    fn = ->
      b.set num
      c.set num
      num

    a = new OutletMethod fn, {}, silent: true
    a.outflows.add bar = sinon.spy ->
    a.run()

    expect(count).eq 2
    expect(bar).calledOnce

  describe 'when func returns another outlet', ->
    it 'should have a value equal to the other outlet', ->
      a = new Outlet 42
      b = new Outlet 43
      tf = new Outlet true

      om = new OutletMethod (->
        if tf.get()
          a
        else
          b),{}

      expect(om.get()).eq 42

    it 'should cascade when the other outlet changes', ->
      a = new Outlet 42
      b = new Outlet 43
      tf = new Outlet true

      om = new OutletMethod (->
        if tf.get()
          a
        else
          b),{}

      q = new Outlet om

      expect(om.get()).eq 42
      expect(q.get()).eq 42
      a.set(43)
      expect(om.get()).eq 43
      expect(q.get()).eq 43

    it 'should unset from the previous outlet when the function result changes', ->
      a = new Outlet 42
      b = new Outlet 44
      tf = new Outlet true

      om = new OutletMethod (->
        if tf.get()
          a
        else
          b),{}

      q = new Outlet om

      expect(om.get()).eq 42
      expect(q.get()).eq 42
      a.set(43)
      expect(om.get()).eq 43
      expect(q.get()).eq 43

      tf.set(false)
      expect(om.get()).eq 44
      expect(q.get()).eq 44
      a.set(999)
      expect(om.get()).eq 44
      expect(q.get()).eq 44
      b.set(45)
      expect(om.get()).eq 45
      expect(q.get()).eq 45

    it 'should not calculate if set to an outlet that\'s currently pending, then update when that outlet is no longer pending', ->
      a = new Outlet 42
      b = new Outlet a
      om = undefined
      c = new Outlet

      Cascade.Block =>
        a.set 43
        om = new OutletMethod (-> b),{}
        c.set om
      expect(om.get()).eq 43
      expect(c.get()).eq 43

