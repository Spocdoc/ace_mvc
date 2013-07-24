clone = lib 'index'
timeout = (a,b) -> setTimeout(b,a)

describe 'clone', ->
  it 'should clone nested objects', ->
    a =
      a: 'hello'
      b:
        c: 42

    b = clone(a)
    expect(b).deep.eq a
    expect(b.a).eq a.a
    expect(b.b).not.eq a.b
    expect(b.b.c).eq a.b.c

  it 'should clone arrays and dates', (done) ->
    a = [
      {one: "foo"},
      {d: new Date(42)}]

    timeout 4, ->
      b = clone(a)
      expect(b).deep.eq a
      expect(b[0]).not.eq a[0]
      expect(b[1]).not.eq a[1]
      expect(b[0].one).eq a[0].one
      expect(b[1].d).not.eq a[1].d
      expect(b[1].d.getTime()).eq a[1].d.getTime()
      done()

  it 'should allow registering custom objects', ->
    constructor = sinon.spy ->
    cloner = sinon.spy ->
    class Foobar
      constructor: constructor

    a = [new Foobar]

    clone.register Foobar, cloner

    b = clone(a)
    expect(constructor).calledOnce
    expect(cloner).calledOnce


