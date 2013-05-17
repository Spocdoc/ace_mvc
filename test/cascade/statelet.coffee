Outlet = lib 'outlet'
Statelet = lib 'statelet'
Cascade = lib 'cascade'
OutletMethod = lib 'outlet_method'

describe 'Statelet', ->
  beforeEach ->
    @value = undefined
    @setter = sinon.spy (arg) => @value = arg
    @getter = sinon.spy ->

    @func = (arg) =>
      if arg?
        @setter(arg) # sets dom value
      else
        @getter() # gets dom value

  it 'should run the setter on set() and nothing on get(), getter() on run()', ->
    s = new Statelet @func
    expect(@getter).calledOnce
    expect(@setter).not.called

    # updates the saved value, then if enableSet is true, runs the setter
    # function and other outflows
    s.set(42)
    expect(@getter).calledOnce
    expect(@setter).calledOnce

    # runs the getter if enableGet is true, else returns saved value
    # if enableGet is true, calls set(newValue)
    s.get()
    expect(@getter).calledOnce
    expect(@setter).calledOnce

    s.run()
    expect(@getter).calledTwice
    expect(@setter).calledOnce

  it 'should take an optional outlet determining when its setter is run', ->
    o = new Outlet false
    s = new Statelet @func, enableSet: o

    s.set(42)
    expect(@setter).not.called

    o.set(true)
    expect(@setter).calledOnce
    expect(@value).eq 42


  it 'should enable direct access to the setter and run every time it\'s invoked', ->
    # may have to run the setter again after updating a dom element elsewhere

    s = new Statelet @func
    s.set(42)
    s.setter()
    s.setter()

    expect(@setter).calledThrice
    expect(@value).eq 42

  it 'should run the setter once at the end of the cascade block', ->
    foo = sinon.spy ->
    s = new Statelet @func, silent: true
    o = new Outlet s
    p = new OutletMethod (o) ->
      foo()
    p.rebind o: o

    expect(foo).calledOnce

    Cascade.Block =>
      s.set(42)
      expect(@setter).not.called

    expect(o.get()).eq 42
    expect(s.get()).eq 42
    expect(foo).calledTwice

    expect(@setter).calledOnce
    expect(@value).eq 42
    expect(@setter).calledAfter(foo)


