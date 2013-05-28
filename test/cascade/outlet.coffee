Outlet = lib 'outlet'
Cascade = lib 'cascade'

numOutflowKeys = 2
timeout = (fn) -> setTimeout(fn, 0)

addCallCounts = ->
  callCounts = {}
  @callCounts = callCounts

  orig = Cascade.prototype._run
  Cascade.prototype._run = ->
    return unless this.pending
    callCounts[this.cid] ?= 0
    ++callCounts[this.cid]
    orig.apply(this, arguments)

describe 'Outlet mild', ->
  beforeEach ->
    @a = new Outlet(1)

  it 'should set the initial value to constructor arg', ->
    expect(@a.get()).eq 1

  it 'should set the value when changed', ->
    @a.set(2)
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
    @a.set 1
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

describe 'Outlet synchronization', ->
  beforeEach ->

  it 'should keep two outlets in sync when one is set to the other', ->
    @a = new Outlet(1)
    @b = new Outlet(2)

    addCallCounts.call this

    @b.set(@a)
    @b.set(42)
    expect(@a.get()).eq 42

  it 'should keep multiple outlets in sync', ->
    @model = new Outlet(1)
    @view1 = new Outlet @model
    @view2 = new Outlet @model

    @model.set(2)
    expect(@model.get()).eq 2
    expect(@view1.get()).eq 2
    expect(@view2.get()).eq 2

    @view1.set(3)
    expect(@model.get()).eq 3
    expect(@view1.get()).eq 3
    expect(@view2.get()).eq 3

  it 'should keep outlets in sync even when one is a function', ->
    @x = new Outlet 42
    @first = new Outlet => 2*@x.get()
    @second = new Outlet @first

    expect(@second.get()).eq 84

    @second.set(2)
    expect(@first.get()).eq 2
    expect(@second.get()).eq 2
    expect(@x.get()).eq 42

    @x.set(43)
    expect(@first.get()).eq 86
    expect(@second.get()).eq 86


describe 'Outlet hot', ->
  beforeEach ->
    @a = new Outlet(1)
    @b = new Outlet(2)

    addCallCounts.call this

    @b.set(@a)

  it 'when the inflow outlet is changed to another outlet, it should not recalculate when the original inflow outlet changes', ->
    expect(@callCounts[@b.cid]).eq 1
    @a1 = new Outlet(3)
    @b.set(@a1)
    expect(@b.get()).eq(@a1.get())
    expect(@callCounts[@b.cid]).eq 2
    @b.unset(@a)
    @a.set(999)
    expect(@callCounts[@b.cid]).eq 2

  it 'should re-fetch a function when recalculated as part of a cascade', ->
    v = 42
    func = sinon.spy ->
      return v
    expect(@callCounts[@a.cid]).not.exist
    @a.set(func)
    expect(@callCounts[@b.cid]).eq 2
    expect(@callCounts[@a.cid]).eq 1
    expect(func).calledOnce

    @c = new Cascade
    @c.outflows.add(@a)
    v = 43
    @c.run()
    expect(@callCounts[@b.cid]).eq 3
    expect(@callCounts[@a.cid]).eq 2
    expect(func).calledTwice

  it 'should not cascade outflows when assigned to a function whose value is the same as the previous value', ->
    x = new Outlet 1
    foo = -> 1
    bar = sinon.spy ->
    x.outflows.add bar
    expect(bar).not.called
    x.set foo
    expect(bar).not.called

  it 'should not cascade outflows when assigned to the same inflow', ->
    foo = -> 1
    x = new Outlet foo
    bar = sinon.spy ->
    x.outflows.add bar
    x.set foo
    expect(bar).not.called

  it 'should not cascade outflows when assigned to a new inflow that gives the same value', ->
    foo = -> 1
    bar = -> 1
    x = new Outlet foo
    out = sinon.spy ->
    x.outflows.add out

    x.set bar
    expect(out).not.called

  describe '#detach', ->

    beforeEach ->
      @a = new Outlet(1)
      @b = new Outlet(2)

      addCallCounts.call this

      @b.set(@a)
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

    it 'should not update a previously attached inflow when updated after detached', ->
      x = new Outlet 1
      y = new Outlet x
      y.set(2)
      expect(x.get()).eq 2
      y.detach()
      x.set(3)
      expect(y.get()).eq 2

  describe 'automatic outflows', ->
    beforeEach ->
      @a = new Outlet(1)
      @b = new Outlet(2)

      addCallCounts.call this

      @b.set(@a)

    it 'should assign inflows when input is a function calling other outlet\'s getters', ->
      x = new Outlet(1)
      y = new Outlet -> 2 * x.get() + 0*x.get()

      x.set(2)
      expect(y.get()).eq 4
      expect(@callCounts[x.cid]).not.exist
      expect(@callCounts[y.cid]).eq 2

      expect(y.inflows[x.cid]).to.exist
      expect(x.outflows[y.cid]).to.exist

      expect(Object.keys(y.inflows).length).eq 1
      expect(y.outflows.length).eq 0

      expect(Object.keys(x.inflows).length).eq 0
      expect(x.outflows.length).eq 1

    it 'should assign inflows only to the direct -- not indirect -- inflows', ->
      x = new Outlet(1)
      y = new Outlet -> 2 * x.get()
      z = new Outlet -> 2 * y.get()

      x.set(2)
      expect(y.get()).eq 4
      expect(z.get()).eq 8
      expect(@callCounts[x.cid]).not.exist
      expect(@callCounts[y.cid]).eq 2
      expect(@callCounts[z.cid]).eq 2

      expect(x.outflows[y.cid]).to.exist
      expect(y.inflows[x.cid]).to.exist
      expect(y.outflows[z.cid]).to.exist
      expect(z.inflows[y.cid]).to.exist

      expect(Object.keys(x.inflows).length).eq 0
      expect(x.outflows.length).eq 1

      expect(Object.keys(y.inflows).length).eq 1
      expect(y.outflows.length).eq 1

      expect(Object.keys(z.inflows).length).eq 1
      expect(z.outflows.length).eq 0

    it 'should remove auto inflows that no longer apply', ->
      b = new Outlet 0
      c = new Outlet 2
      calls = 0

      a = new Outlet ->
        ++calls
        if b.get()
          c.get()
        return

      expect(calls).eq 1
      c.set(3)
      expect(calls).eq 1
      b.set(1)
      expect(calls).eq 2
      c.set(42)
      expect(calls).eq 3
      b.set(0)
      expect(calls).eq 4
      c.set(43)
      expect(calls).eq 4

describe 'Outlet habanero', ->
  beforeEach ->
    @f = new Outlet 2

    @afn = sinon.spy => Math.floor(@f.get())
    @a = new Outlet @afn

    @bfn = sinon.spy => @a.get()*2
    @b = new Outlet @bfn

    @dfn = sinon.spy => @f.get()*2
    @d = new Outlet @dfn

    @cfn = sinon.spy => @a.get()*3 + @d.get()*2 + @f.get()
    @c = new Outlet @cfn

    @efn = sinon.spy => @c.get()*2
    @e = new Outlet @efn

    @expectValues = (f) ->
      expect(@f.get()).eq(f)
      expect(@a.get()).eq(a = Math.floor(f))
      expect(@b.get()).eq(b = 2*a)
      expect(@d.get()).eq(d = 2*f)
      expect(@c.get()).eq(c = 3*a+2*d+f)
      expect(@e.get()).eq(e = 2*c)

  it 'should have the expected values given complex initial dependencies', ->
    @expectValues(2)

  it 'should have the expected inflows & outflows given complex initial dependencies', ->
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


  it 'should have run the calculation functions exactly once with complex dependencies', ->
    expect(@afn).calledOnce
    expect(@bfn).calledOnce
    expect(@cfn).calledOnce
    expect(@dfn).calledOnce
    expect(@efn).calledOnce

  it 'should run the appropriate outflows in the right order', ->
    # TODO this test is flawed -- all the functions were called in this order during initialization...
    @f.set(2.2)

    expect(@cfn).calledAfter(@afn)
    expect(@cfn).calledAfter(@dfn)
    expect(@efn).calledAfter(@cfn)

  it 'should run the appropriate outflows when some results change and others don\'t', ->
    @f.set(2.2)
    @expectValues(2.2)

    expect(@afn).calledTwice
    expect(@bfn).calledOnce
    expect(@cfn).calledTwice
    expect(@dfn).calledTwice
    expect(@efn).calledTwice

describe 'Outlet stopPropagation', ->
  it 'should still call when one inflow is pending then becomes stopPropagate', ->
    d = new Outlet(42)
    a = new Outlet fn_a = sinon.spy -> d.get() * 2
    b = new Outlet fn_b = sinon.spy -> 2
    c = new Outlet fn_c = sinon.spy -> a.get() + b.get()

    d.outflows.add a
    d.outflows.add b
    a.outflows.add c
    b.outflows.add c

    expect(fn_a).calledOnce
    expect(fn_b).calledOnce
    expect(fn_c).calledOnce
    expect(c.get()).eq (42*2+2)

    d.set(43)
    expect(fn_a).calledTwice
    expect(fn_b).calledTwice
    expect(fn_c).calledTwice
    expect(c.get()).eq (43*2+2)

  it 'should not call when pending and all inflows call stopPropagate', ->
    d = new Outlet(42)
    a = new Outlet fn_a = sinon.spy -> 2
    b = new Outlet fn_b = sinon.spy -> 2
    c = new Outlet fn_c = sinon.spy -> a.get() + b.get()

    d.outflows.add a
    d.outflows.add b
    a.outflows.add c
    b.outflows.add c

    expect(fn_a).calledOnce
    expect(fn_b).calledOnce
    expect(fn_c).calledOnce
    expect(c.get()).eq (4)

    d.set(43)
    expect(fn_a).calledTwice
    expect(fn_b).calledTwice
    expect(fn_c).calledOnce
    expect(c.get()).eq (4)

describe 'Outlet async', ->
  it 'calls the outflows only after the callback is invoked', (fin) ->
    afn0 = sinon.spy ->
    afn1 = sinon.spy ->
    afn2 = sinon.spy ->
    afn3 = sinon.spy ->
    bfn1 = sinon.spy ->
    cfn1 = sinon.spy ->

    d = new Outlet(42)

    a = new Outlet (done) ->
      afn0()
      if (d.get() > 42)
        afn1()
        timeout ->
          afn2()
          done(2)
      else
        afn3()
        done(1)

    expect(afn0).calledOnce
    expect(afn1).not.called
    expect(afn3).calledOnce
    expect(d.outflows[a.cid]).exist
    expect(a.get()).eq 1

    b = new Outlet ->
      bfn1()
      2 * a.get()

    c = new Outlet ->
      cfn1()
      if (b.get() == 4)
        timeout ->
          timeout ->
            expect(bfn1).calledTwice
            expect(afn0).calledTwice
            expect(afn1).calledOnce
            expect(afn2).calledOnce
            expect(afn3).calledOnce
            expect(cfn1).calledTwice
            fin()

    d.set(43)

  it 'tracks dependencies in the synchronous part of the call', (fin) ->
    bfn1 = sinon.spy ->
    a = new Outlet 42
    b = new Outlet (done) ->
      bfn1()
      q = a.get()
      timeout ->
        if q == 43
          expect(bfn1).calledTwice
          done()
          fin()
        else
          done()
    a.set(43)

  it  'should accept only the value of the most recent call', (fin) ->
    c = new Outlet 0

    afn2 = sinon.spy ->
    afn3 = sinon.spy ->
    bfn1 = sinon.spy ->

    a = new Outlet (done) ->
      switch c.get()
        when 0 then done(0)
        when 1
          timeout ->
            timeout ->
              timeout ->
                expect(afn2).calledOnce
                expect(afn3).calledOnce
                expect(bfn1).calledOnce
                done(1)
                timeout ->
                  timeout ->
                    timeout ->
                      timeout ->
                        fin()
        when 2
          timeout ->
            afn2()
            done(2)
        when 3
          timeout ->
            timeout ->
              expect(afn2).calledOnce
              afn3()
              done(3)

    b = new Outlet ->
      switch a.get()
        when 0 then return
        else
          bfn1()
          expect(a.get()).eq 3
          expect(afn2).calledOnce
          expect(afn3).calledOnce

    c.set(1)
    c.set(2)
    c.set(3)

  it 'should ignore the async call if it\'s set explicitly before the async returns', (fin) ->

    c = new Outlet 0

    a = new Outlet (done) ->
      switch c.get()
        when 0 then done(0)
        else
          timeout ->
            done(999)
            timeout ->
              timeout ->
                expect(a.get()).eq 2
                fin()

    c.set(1)
    a.set(2)

describe 'Outlet with objects', ->
  # TODO: changed() is in work in progress
  # it 'should always recalculate when set to an object', ->
  #   arr = [1,2,3]
  #   arg = undefined
  #   a = new Outlet arr
  #   b = sinon.spy (argg) -> arg = argg
  #   a.outflows.add b
  #   expect(b.calledOnce)
  #   arr.push(4)
  #   expect(b.calledOnce)
  #   a.changed()
  #   expect(b.calledTwice)
  #   expect(arg).eq.arr

  it 'should handle interdependent object-valued outlets', ->
    a = new Outlet
    b = new Outlet
    a.set(b)
    v = [1,2,3,4]
    a.set(v)
    expect(b.get()).eq v
    expect(a.get()).eq v
    v = [1,2,3,4,5]
    b.set(v)
    expect(b.get()).eq v
    expect(a.get()).eq v

  it 'should calculate a changed object outflow once when multiple outlets cause it to change in a block', ->
    foo = sinon.spy ->

    ops = []
    updater = new Outlet foo, silent: true

    outlets = [
      new Outlet
      new Outlet
      new Outlet
    ]

    pushers = []

    letters = "abc"

    for i in [0..2]
      do (i) ->
        outlet = new Outlet
        pushers.push outlet

        fn = ->
          ops.push letters[i]
          outlet.modified()
        outlet.set fn, silent: true

        outlets[i].outflows.add outlet
        outlet.outflows.add updater

    expect(foo).not.called

    Cascade.Block =>
      outlets[i].set 1 for i in [0..2]

    expect(ops).deep.eq ['c','b','a']
    expect(foo).calledOnce

    ops = []

    Cascade.Block =>
      outlets[i].set 2 for i in [0..2]

    expect(ops).deep.eq ['c','b','a']
    expect(foo).calledTwice

  describe '#get(args...)', ->
    it 'should invoke underlying object\'s get(args) when called with arguments', ->
      foo = sinon.spy ->
      bar = sinon.spy ->

      obj =
        get: (arg) ->
          bar()
          return @ unless arg?
          foo()
          "yay"

      outlet = new Outlet obj

      expect(foo).not.called
      expect(bar).calledOnce
      expect(outlet.get()).eq obj
      expect(foo).not.called
      expect(bar).calledOnce

      expect(outlet.get(123)).eq 'yay'
      expect(foo).calledOnce
      expect(bar).calledTwice

      expect(outlet.get()).eq obj
      expect(foo).calledOnce
      expect(bar).calledTwice

describe 'Outlet #modified', ->
  it 'should run all the outflows even if the object is the same', ->
    foo = sinon.spy ->

    obj = { foo: 'bar'}

    a = new Outlet obj
    b = new Outlet a
    c = new Outlet b
    c.outflows.add foo

    a.set(obj)
    expect(foo).not.called

    a.modified()
    expect(foo).calledOnce

describe 'Outlet set to multiple functions', ->
  it 'should run the function based on inflows', ->
    x = new Outlet 1
    y = new Outlet 2

    a = new Outlet
    a.set -> 2*x.get()
    a.set -> 3*y.get()

    b = new Outlet a

    expect(a.get()).eq 6
    expect(b.get()).eq a.get()

    x.set(42)
    expect(a.get()).eq 84
    expect(b.get()).eq a.get()

    y.set(42)
    expect(a.get()).eq 126
    expect(b.get()).eq a.get()

describe 'Outlet unrun cascade', ->
  it 'should allow setting several times in a block and run once with the right final value', ->
    a = undefined
    b = undefined

    Cascade.Block =>
      a = new Outlet 42
      b = new Outlet a
      b.set(43)

    expect(a.get()).eq 43
    expect(b.get()).eq 43
