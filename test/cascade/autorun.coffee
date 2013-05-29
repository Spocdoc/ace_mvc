Auto = lib 'auto'
Outlet = lib 'outlet'

describe 'Auto', ->
  it 'should return nothing and run automatically when invoked as a block', ->
    x = new Outlet 1
    y = 0
    foo = sinon.spy (val) ->
      y = val

    ret = Auto ->
      foo x.get()

    expect(ret).not.exist

    expect(foo).calledOnce
    expect(y).eq 1

    x.set(2)
    expect(foo).calledTwice
    expect(y).eq 2

  it 'should return an Auto instance and still "auto run" when invoked with new', ->
    x = new Outlet 1
    y = 0
    foo = sinon.spy (val) ->
      y = val

    a = new Auto ->
      foo x.get()

    expect(a).instanceof Auto

    expect(foo).calledOnce
    expect(y).eq 1

    x.set(2)
    expect(foo).calledTwice
    expect(y).eq 2

  # detaching now detaches the original function, too (it's not treated specially...)
  # it 'should return an Auto instance that can be detached from inputs then manually run() again', ->
  #   x = new Outlet 1
  #   y = 0
  #   foo = sinon.spy (val) ->
  #     y = val

  #   a = new Auto ->
  #     foo x.get()

  #   a.detach()

  #   x.set(2)
  #   expect(foo).calledOnce
  #   expect(y).eq 1

  #   a.run()
  #   expect(foo).calledTwice
  #   expect(y).eq 2



