adiff = lib 'array'

restore = (a,b,options) ->
  diff = adiff.diff(a,b,options)
  try
    expect(adiff.apply(a,diff)).deep.eq b
  catch e
    console.error "a:",a,"b:",b
    throw e

randArray = (n) ->
  a = []
  a.push Math.floor Math.random()*10 while n--
  a


describe.only 'array diff', ->
  it 'should return the same result without move', ->
    restore \
      [1,2,3,4,6,7,8,9,9],
      [4,1,2,3,4,5]

  it 'should return the same result without move with identical arrays', ->
    restore \
      [1,2,3],
      [1,2,3]

  it 'should return the same result with a move that inserts early', ->
    restore \
      [1,2,3],
      [3,1,2],
      move: true

  it 'should return the same result with a move that inserts late', ->
    restore \
      [3,1,2],
      [1,2,3],
      move: true

  it 'should return the same result for random complex arrays with move', ->
    a = randArray(50)
    b = randArray(80)
    restore a, b,
      move: true
    restore b, a,
      move: true

  it 'should return the same results, but shorter with replacement', ->
    a = [1,2,3]
    b = [4,2,3]

    base = adiff.diff a,b
    repl = adiff.diff a,b, replace: true

    expect(repl.length).lt base.length

    expect(adiff.apply(a,base)).deep.eq(adiff.apply(a,repl))

  it 'should allow a hash function', ->
    a = [{a:1},2,3]
    b = [2,3,{a:2}]

    base = adiff.diff a,b, move: true, hash: (o) ->
      return o if typeof o is 'number'
      return o.a

    expect(base[1].v).deep.eq({a:2})
    expect(adiff.apply a, base).deep.eq b

    base = adiff.diff a,b, move: true, hash: (o) ->
      return o if typeof o is 'number'
      return o.a > 0

    expect(base[1].v).not.exist
    expect(adiff.apply a, base).deep.eq [2,3,{a:1}]

