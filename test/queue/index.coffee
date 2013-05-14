queue = lib 'index'

describe 'queue', ->
  it 'should enqueue and dequeue large numbers of elements in order', ->
    a = [1..999]
    q = queue()
    q(v) for v in a
    for v in a
      expect(q()).eq v

    return


