diff = lib 'index'

describe 'diff', ->
  it 'should accept a path and stub out objects', ->
    from = {_id: 'id', _v: 0}
    path = ['foo','bar',1,'baz']
    to = {hello: 'world'}
    d = diff(from,to,path: path)


    result = {_id: 'id', _v: 0, foo: { bar: [null, baz: {hello: 'world'}] } }
    from = diff.patch(from, d)

    # there's something wrong with deep.eq...
    expect(JSON.stringify from).eq JSON.stringify result

  it 'should diff deep keys', ->
    from = {_id: 'id', _v: 0, foo: { bar: [null, baz: {hello: 'world'}] } }
    to = {hello: 'mundo'}
    result = {_id: 'id', _v: 0, foo: { bar: [null, baz: {hello: 'mundo'}] } }
    path = ['foo','bar',1,'baz']
    d = diff(from, to, path: path)
    from = diff.patch(from, d)
    expect(JSON.stringify from).eq JSON.stringify result

  it 'should clone objects in the diff', ->
    a = {foo: 'foo'}
    b = {foo: {bar: 'baz'}}
    d = diff(a,b)
    b.foo.bazoo = 'fro'
    b.foo.bar = 'bazrr'

    bp = diff.patch(a,d)
    expect(bp).deep.eq {foo: {bar: 'baz'}}

    bp.foo.bazoo = 'foo'
    bp.foo.bar = 'bazoo'
    bpp = diff.patch(a,d)
    expect(bpp).deep.eq {foo: {bar: 'baz'}}


