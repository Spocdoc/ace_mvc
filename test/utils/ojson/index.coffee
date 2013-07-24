OJSON = lib 'index'
{extend, include} = lib '../mixin'

class Foo
  constructor: (@_value) ->
  toJSON: -> @_value
  # @fromJSON: (arg) -> new @(arg)

class Bar extends Foo
  toString: -> "bar #{@_value}"

OJSON.register 'Foo': Foo
OJSON.register 'Bar': Bar

thruJSON = (obj) ->
  OJSON.parse OJSON.stringify OJSON.parse OJSON.stringify obj

ojsonTest = (OJSON) ->
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

    OJSON.register 'Nest': Nest
    try
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
    finally
      OJSON.unregister 'Nest'
    
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

    OJSON.register 'Super1': Super1,
      'Super2': Super2,
      {'Orange1': Super1.Orange,
      'Orange2': Super2.Orange}

    try
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
    finally
      OJSON.unregister 'Super1', 'Super2', 'Orange1', 'Orange2'

  it 'should not include "classes" that haven\'t been registered, but should include objects', ->
    class View
      constructor: (@_value) ->

    doc = {a: new View(42), b: "foo!", c: -> }
    str = OJSON.stringify(doc)
    expect(typeof str).eq 'string'
    doc = OJSON.parse str
    expect(doc).exist
    expect(doc.a).not.exist
    expect(doc.c).not.exist
    expect(doc.b).eq 'foo!'

  it 'should not register anonymous types', ->
    Compound = ->
    expect(-> OJSON.register Compound).to.throw(Error)

  it 'should only include own properties', ->
    class Compound
    a = new Compound
    jsonF = sinon.spy ->
    class F
      toJSON: jsonF
    a.foo = new F
    b = Object.create a
    b.bar = 'baz'

    OJSON.register 'F': F
    OJSON.register 'Compound': Compound
    try
      extend Compound, OJSON.copyKeys
      str = OJSON.stringify b
      expect(typeof str).eq 'string'

      b = OJSON.parse str
      expect(b).exist
      expect(b.bar).eq 'baz'
      expect(b.foo).not.exist
      expect(jsonF).not.called
    finally
      OJSON.unregister 'F', 'Compound'

  it 'should rebuild arrays in order', ->
    a = sinon.spy ->
    b = sinon.spy ->
    c = sinon.spy ->
    class A
      constructor: -> @foo = 'bar'
      @fromJSON: a
    class B
      @fromJSON: b
    class C
      @fromJSON: c

    OJSON.register 'A':A, 'B':B, 'C':C

    try
      obj = [new A, new B, new C]
      obj = OJSON.parse OJSON.stringify obj
      expect(a).calledBefore(b)
      expect(b).calledBefore(c)
    finally
      OJSON.unregister 'A','B','C'

  it 'should allow registration & unregistration', ->
    class Fro
    class Bro
    OJSON.register 'Fro': Fro
    expect(-> OJSON.register 'Fro': Bro).to.throw(Error)
    OJSON.unregister 'Fro'
    OJSON.register 'Fro': Fro
    expect(-> OJSON.register 'Fro': Bro).to.throw(Error)
    OJSON.unregister 'Fro'

  it 'should allow registration & unregistration by name', ->
    class Fro
    desc = {'Uno': Fro}
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister desc
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister desc

  it 'should allow registration by name=>Constructor and unregistration by name only', ->
    class Fro
    name = 'Uno'
    desc = {'Uno': Fro}
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister name
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister name

describe 'OJSON', ->
  describe 'with Arrays', ->
    before ->
      OJSON.useArrays = true

    ojsonTest(OJSON)

    it 'should use array format', ->
      a =
        one: 1
        two: 2
        three: [1,2, {
          foo: 'bar'
          baz: [4,5,6]}]

      str = OJSON.stringify a
      expect(str.indexOf('$Array')).eq -1
      b = OJSON.parse str
      expect(b).not.eq a
      expect(b).deep.eq a

  describe 'without Arrays', ->
    before ->
      OJSON.useArrays = false

    ojsonTest(OJSON)

    it 'should not use array format', ->
      a =
        one: 1
        two: 2
        three: [1,2, {
          foo: 'bar'
          baz: [4,5,6]}]

      str = OJSON.stringify a
      expect(str.indexOf('$Array')).not.eq -1
      b = OJSON.parse str
      expect(b).not.eq a
      expect(b).deep.eq a




