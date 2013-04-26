OJSON = lib 'ojson'
{extend, include} = lib '../mixin/mixin'

class Foo
  constructor: (@_value) ->
  toJSON: -> @_value
  # @fromJSON: (arg) -> new @(arg)

class Bar extends Foo
  toString: -> "bar #{@_value}"

OJSON.register Foo
OJSON.register Bar

describe.only 'OJSON', ->
  describe '#stringify', ->
    it 'should form a string', ->
      a = new Bar(42)
      str = OJSON.stringify a
      expect(typeof str).eq 'string'

  it 'should serialize and restore inherited types', ->
    a = new Bar(42)
    str = OJSON.stringify a
    a = OJSON.parse str
    expect(a).instanceof Bar
    expect(a.toString()).eq 'bar 42'

  it 'should serialize and restore Dates', ->
    ms = 1366997102210
    a = new Date(ms)
    a = OJSON.parse OJSON.stringify a
    expect(a.getTime()).eq ms

  it 'should serialize and restore arrays of objects', ->
    a = [ new Bar(1), new Bar(2), new Bar(3) ]
    a = OJSON.parse OJSON.stringify a
    expect(a[0]).instanceof Bar
    expect(a[1]).instanceof Bar
    expect(a[2]).instanceof Bar
    expect(a[0].toString()).eq 'bar 1'
    expect(a[1].toString()).eq 'bar 2'
    expect(a[2].toString()).eq 'bar 3'
    expect(a.length).eq 3

  it 'should serialize nested objects', ->
    class Nest
      constructor: (@_val) ->
        @_val ?= new Bar(42)

    extend Nest, OJSON.copyKeys

    OJSON.register Nest
    a = [ new Nest(new Bar(1)), new Nest(new Bar(2)) ]

    str = OJSON.stringify a
    expect(typeof str).eq 'string'
    a = OJSON.parse str
    expect(Array.isArray(a)).true
    expect(a[0]).instanceof Nest
    expect(a[1]).instanceof Nest
    expect(a[0]._val).instanceof Bar
    expect(a[1]._val).instanceof Bar
    expect(a[0]._val.toString()).eq 'bar 1'
    expect(a[1]._val.toString()).eq 'bar 2'
    
  it 'should allow registering a class with a custom identifier', ->
    class Super1
      class @Orange
        constructor: (@_value1) ->
        toJSON: -> @_value1
        toString: -> "orange1 #{@_value1}"

    class Super2
      class @Orange
        constructor: (@_value2) ->
        toJSON: -> @_value2
        toString: -> "orange2 #{@_value2}"

    OJSON.register Super1,
      Super2,
      {Orange1: Super1.Orange,
      Orange2: Super2.Orange}

    a = new Super1.Orange(1)
    b = new Super2.Orange(2)
    doc = {a: a, b: b}
    str = OJSON.stringify doc
    expect(typeof str).eq 'string'
    doc = OJSON.parse str
    expect(doc.a).instanceof Super1.Orange
    expect(doc.b).instanceof Super2.Orange
    expect(doc.a.toString()).eq 'orange1 1'
    expect(doc.b.toString()).eq 'orange2 2'

