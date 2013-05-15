adiff = lib 'array'

restore = (a,b,options) ->
  diff = adiff.diff(a,b,options)
  try
    expect(adiff.patch(a,diff)).deep.eq b
  catch e
    console.error "a:",a,"b:",b
    throw e

randArray = (n) ->
  a = []
  a.push Math.floor Math.random()*10 while n--
  a


describe 'array diff', ->
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

  it 'should work with replacement', ->
    a = [1,2,3]
    b = [4,2,3]

    base = adiff.diff a,b
    repl = adiff.diff a,b, replace: true

    expect(adiff.patch(a,base)).deep.eq(adiff.patch(a,repl))
    expect(repl).not.deep.eq base

  it 'should allow a hash function', ->
    a = [{a:1},2,3]
    b = [2,3,{a:2}]

    base = adiff.diff a,b, move: true, hash: (o) ->
      return o if typeof o is 'number'
      return o.a

    expect(base[1].v).deep.eq({a:2})
    expect(adiff.patch a, base).deep.eq b

    base = adiff.diff a,b, move: true, hash: (o) ->
      return o if typeof o is 'number'
      return o.a > 0

    expect(base[1].v).not.exist
    expect(adiff.patch a, base).deep.eq [2,3,{a:1}]

  it 'should allow a push operation', ->
    diff = [ {o: 1, i: -1, v:4} ]
    a = [1,2,3]
    b = adiff.patch(a,diff)
    expect(b).deep.eq [1,2,3,4]

  it 'should allow multiple push operations', ->
    diff = [ {o: 1, i: -1, v:4}, {o: 1, i: -1, v:5}]
    a = [1,2,3]
    b = adiff.patch(a,diff)
    expect(b).deep.eq [1,2,3,4,5]

  it 'should allow pop', ->
    diff = [ {o: -1, i: -1} ]
    a = [1,2,3]
    b = adiff.patch(a,diff)
    expect(b).deep.eq [1,2]

  it 'should allow multiple pops', ->
    diff = [ {o: -1, i: -1}, {o: -1, i: -1} ]
    a = [1,2,3]
    b = adiff.patch(a,diff)
    expect(b).deep.eq [1]

  it 'should not append if the \'u\' element is present', ->
    diff = [ {o: 1, i: -1, u: 2} ]
    a = [1,2,3]
    b = adiff.patch(a,diff)
    expect(b).deep.eq a

  it 'should append if the \'u\' element isn\'t present', ->
    diff = [ {o: 1, i: -1, u: 42} ]
    a = [1,2,3]
    b = adiff.patch(a,diff)
    expect(b).deep.eq [1,2,3,42]
