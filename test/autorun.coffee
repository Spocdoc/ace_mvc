Autorun = require '../autorun'
Outlet = require '../outlet'

describe 'Autorun', ->
  it 'should return nothing and run automatically when invoked as a block', ->
    x = new Outlet 1
    y = 0
    foo = sinon.spy (val) ->
      y = val

    ret = Autorun ->
      foo x.get()

    expect(ret).not.exist

    expect(foo).calledOnce
    expect(y).eq 1

    x.set(2)
    expect(foo).calledTwice
    expect(y).eq 2

  it 'should return an Autorun instance and still "auto run" when invoked with new', ->
    x = new Outlet 1
    y = 0
    foo = sinon.spy (val) ->
      y = val

    a = new Autorun ->
      foo x.get()

    expect(a).instanceof Autorun

    expect(foo).calledOnce
    expect(y).eq 1

    x.set(2)
    expect(foo).calledTwice
    expect(y).eq 2

  it 'should return an Autorun instance that can be detached from inputs then manually run() again', ->
    x = new Outlet 1
    y = 0
    foo = sinon.spy (val) ->
      y = val

    a = new Autorun ->
      foo x.get()

    a.detach()

    x.set(2)
    expect(foo).calledOnce
    expect(y).eq 1

    a.run()
    expect(foo).calledTwice
    expect(y).eq 2



