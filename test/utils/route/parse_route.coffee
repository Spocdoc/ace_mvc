parseRoute = lib 'parse_route'
Outlet = lib '../outlet'

describe '#parseRoute', ->
  it 'should return the expected keys for a simple path', ->
    [regex] = parseRoute '/:foo/:bar', keys=[]
    expect(keys.length).eq 2
    expect(keys[0].name).eq 'foo'
    expect(keys[1].name).eq 'bar'
    expect(keys[0].optional).false
    expect(keys[1].optional).false

  it 'should return expected key values when matched against simple path', ->
    [regex] = parseRoute '/:foo/:bar', keys=[]
    m = regex.exec '/foo/bar'
    expect(m[1]).eq 'foo'
    expect(m[2]).eq 'bar'

  it 'should return not match simple path missing keys', ->
    [regex] = parseRoute '/:foo/:bar', keys=[]
    m = regex.exec '/foo'
    expect(m).not.exist

  it 'should return the expected keys for a path with optional keys', ->
    [regex] = parseRoute '/:foo/:bar?', keys=[]
    expect(keys.length).eq 2
    expect(keys[0].name).eq 'foo'
    expect(keys[1].name).eq 'bar'
    expect(keys[0].optional).false
    expect(keys[1].optional).true

  it 'should return expected key values when matched against simple path with optional keys', ->
    [regex] = parseRoute '/:foo/:bar?', keys=[]
    m = regex.exec '/foo'
    expect(m[1]).eq 'foo'
    expect(m[2]).not.exist

  it 'should respect fixed text', ->
    [regex] = parseRoute '/foo/:bar?', keys=[]
    expect(keys.length).eq 1
    expect(keys[0].name).eq 'bar'
    expect(keys[0].optional).true

    expect(regex.exec '/fro/so').not.exist
    m = regex.exec '/foo/so'
    expect(m[1]).eq 'so'

    [regex] = parseRoute '/foo/:bar/:baz/:bo', keys=[]

  it 'should respect captures', ->
    [regex] = parseRoute '/foo/:bar(fixed)?/:baz', keys=[]
    expect(keys.length).eq 2
    expect(keys[0].name).eq 'bar'
    expect(keys[1].name).eq 'baz'
    expect(keys[0].optional).true
    expect(keys[1].optional).false
    m = regex.exec '/foo/fixed/mo'
    expect(m[1]).eq 'fixed'
    expect(m[2]).eq 'mo'

    m = regex.exec '/foo/bar/mo'
    expect(m).not.exist

  it 'should reform a simple url', ->
    [regex,fn] = parseRoute '/:foo/:bar', keys=[]
    outlets =
      'foo': new Outlet 'foovalue'
      'bar': new Outlet 'barvalue'
    str = fn(outlets)
    expect(str).eq '/foovalue/barvalue'

  it 'should reform a url with fixed text and optional parameters', ->
    [regex,fn] = parseRoute '/:foo/view.:format?', keys=[]
    outlets =
      'foo': new Outlet 'foovalue'
    str = fn(outlets)
    expect(str).eq '/foovalue/view'

    outlets =
      'foo': new Outlet 'foovalue'
      'format': new Outlet 'json'
    str = fn(outlets)
    expect(str).eq '/foovalue/view.json'

  it 'should reform a url with fixed text, captures and optional parameters', ->
    [regex,fn] = parseRoute '/foo/:bar(fixed)?/:baz', keys=[]
    outlets =
      'bar': new Outlet 'fixed'
      'baz': new Outlet 'mo'
    str = fn outlets
    expect(str).eq '/foo/fixed/mo'

    outlets =
      'baz': new Outlet 'mo'
    str = fn outlets
    expect(str).eq '/foo/mo'

