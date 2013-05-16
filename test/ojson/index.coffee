OJSON = lib 'index'
{extend, include} = lib '../mixin/mixin'

class Foo
  constructor: (@_value) ->
  toJSON: -> @_value
  # @fromJSON: (arg) -> new @(arg)

class Bar extends Foo
  toString: -> "bar #{@_value}"

OJSON.register Foo
OJSON.register Bar

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

    OJSON.register Nest
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
      OJSON.unregister Nest
    
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
      OJSON.unregister Super1, Super2, 'Orange1', 'Orange2'

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

    OJSON.register F
    OJSON.register Compound
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
      OJSON.unregister F, Compound

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

    OJSON.register A, B, C

    try
      obj = [new A, new B, new C]
      obj = OJSON.parse OJSON.stringify obj
      expect(a).calledBefore(b)
      expect(b).calledBefore(c)
    finally
      OJSON.unregister A, B, C

  it 'should allow registration & unregistration', ->
    class Fro
    OJSON.register Fro
    expect(-> OJSON.register Fro).to.throw(Error)
    OJSON.unregister Fro
    OJSON.register Fro
    expect(-> OJSON.register Fro).to.throw(Error)
    OJSON.unregister Fro

  it 'should allow registration & unregistration by name', ->
    class Fro
    desc = {Uno: Fro}
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister desc
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister desc

  it 'should allow registration by name=>Constructor and unregistration by name only', ->
    class Fro
    name = 'Uno'
    desc = {Uno: Fro}
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister name
    OJSON.register desc
    expect(-> OJSON.register desc).to.throw(Error)
    OJSON.unregister name


  describe 'references', ->
    before ->
      class @A
        constructor: -> @foo = 'bar'
        _ojson: true
      OJSON.register {another_a: @A}

      class @B
      extend @B, OJSON.copyKeys
      OJSON.register {another_b: @B}

    after ->
      OJSON.unregister 'another_a','another_b'


    it 'should create unique ids for objects with `true` _ojson fields (including inherited)', ->
      a = new @A
      str = OJSON.stringify a
      expect(str.indexOf('_ojson')).not.eq -1

    it 'should not create unique ids if the object has a toJSON method', ->
      a = new Bar(42)
      a._ojson = true
      str = OJSON.stringify a
      expect(str.indexOf('_ojson')).eq -1

    it 'should add OJSONRef\'s to the object when referenced', ->
      a = new @A
      b = new @B
      b.a = a

      doc = [a, b]
      str = OJSON.stringify doc
      doc = OJSON.parse str
      expect(doc[1].a).eq doc[0]
      expect(doc[0].foo).eq 'bar'
      expect(doc[0]._ojson).eq true

    it 'should also restore references to plain objects', ->
      a = {foo: 'bar', _ojson: true}
      b = {a: a, b: 'yay b'}
      doc = [a, b]
      str = OJSON.stringify doc
      doc = OJSON.parse str
      expect(doc[1].a).eq doc[0]

    it 'should allow a chain of referenced, inherited objects', ->
      class C
        _ojson: true
        OJSON.register {C123: @}
        @fromJSON: (obj) ->
          if obj._parent?
            inst = Object.create obj._parent
            inst._parent = obj._parent
          else
            inst = new @
          inst[k] = v for k,v of obj when k not in ['_parent', '_ojson']
          inst

      try
        chain = []
        chain[0] = new C
        for i in [1..10]
          chain[i] = Object.create(parent=chain[i-1])
          chain[i]._parent = parent

        chain[0].foo = {foo: 'bar'}
        chain[3].foo = {foo: 'baz'}

        str = OJSON.stringify chain
        chain = OJSON.parse str

        for i in [0..10]
          expect(chain[i]).instanceof C

        for i in [1...3]
          expect(chain[i].foo).eq chain[0].foo

        for i in [3..10]
          expect(chain[i].foo).eq chain[3].foo

        expect(chain[0].foo.foo).eq 'bar'
        expect(chain[3].foo.foo).eq 'baz'
      finally
        OJSON.unregister 'C123'

    it 'should restore _ojson when inherited and when not', ->
      try
        class @D
          constructor: ->
            @foo = 'bar'
            @_ojson = true
          _ojson: true
        OJSON.register {another_d: @D}

        class @E extends @D
          constructor: ->
        extend @E, OJSON.copyKeys
        OJSON.register {another_e: @E}

        hasOwn = {}.hasOwnProperty

        a = new @D
        b = new @E
        doc = [a,b]

        expectations = =>
          expect(hasOwn.call(doc[0], '_ojson')).true
          expect(hasOwn.call(doc[1], '_ojson')).false

        expectations()

        doc = thruJSON doc

        expectations()

      finally
        OJSON.unregister 'another_e', 'another_d'

    it 'should serialize object keys in a deterministic order', ->
      a = {a: 1, b: 2, c: 3}
      b = {c: 3, a: 1, b: 2}
      expect(OJSON.stringify a).eq(OJSON.stringify b)


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




