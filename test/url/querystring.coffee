qs = lib 'querystring'

describe 'querystring#parse', ->
  it 'should parse simple key values', ->
    str = 'foo=bar&baz=bo'
    obj = {foo: 'bar', baz: 'bo' }
    result = qs.parse str
    expect(result).deep.eq obj

  it 'should parse arrays', ->
    str = 'foo=bar1&baz=bo&foo=bar2'
    obj = {foo: ['bar1', 'bar2'], baz: 'bo'}
    result = qs.parse str
    expect(result).deep.eq obj
    
  it 'should parse arrays with [] as []', ->
    str = 'foo[]=bar1&baz=bo&foo[]=bar2'
    result = qs.parse str
    expect(result).deep.eq {'foo[]': ['bar1', 'bar2'], baz: 'bo'}

  it 'should not parse bools and numbers', ->
    str = 'bool=true&bool=false&num=1&num=2'
    result = qs.parse str
    expect(result).deep.eq {'bool': ['true', 'false'], num: ['1','2']}

describe 'querystring#stringify', ->
  it 'should stringify simple key values', ->
    str = 'foo=bar&baz=bo'
    obj = {foo: 'bar', baz: 'bo' }
    expect(qs.stringify obj).eq str

  it 'should stringify arrays', ->
    str = 'foo=bar1&foo=bar2&baz=bo'
    obj = {foo: ['bar1', 'bar2'], baz: 'bo'}
    expect(qs.stringify obj).eq str

  it 'should accept a name parameter for a primitive', ->
    str = qs.stringify 'bar', 'foo'
    expect(str).eq('foo=bar')

  it 'should accept a name parameter for an array', ->
    str = qs.stringify ['bar1','bar2'], 'foo'
    expect(str).eq('foo=bar1&foo=bar2')

