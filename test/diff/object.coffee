diff = lib 'index'
odiff = lib 'object'

describe 'object diff', ->
  describe '#changes', ->
    it 'should handle string, array and numeric values by replacement', ->
      a = {
        one: 'hello'
        two: [1,2,3]
        three: 42
      }

      b = {
        one: 'hellop'
        two: [1,2,3,4]
        three: 43
      }

      d = diff(a,b)
      expect(diff.patch(a,d)).deep.eq b

      changes = odiff.changes d, b
      expect(Object.keys(changes).length).eq 1
      expect(Object.keys(changes[1]).length).eq 3
      expect(changes[1].one).eq b.one
      expect(changes[1].two).eq b.two
      expect(changes[1].three).eq b.three

    it 'should recurse through nested objects', ->
      afour = {
          a: 'a'
          b: 'a'
        }

      bfour = {
          a: 'a'
          b: 'b'
        }
      a = {
        one: 'hello'
        two: [1,2,3]
        three: 42
        four: afour
        five: 44
      }

      b = {
        one: 'hellop'
        two: [1,2,3,4]
        three: 43
        four: bfour
        five: 44
      }

      d = diff(a,b)

      changes = odiff.changes d, b

      expect(Object.keys(changes).length).eq 2
      expect(Object.keys(changes[1]).length).eq 3
      expect(Object.keys(changes[0]).length).eq 1
      expect(Object.keys(changes[0].four)).deep.eq ['1']
      expect(changes[0].four).deep.eq odiff.changes(diff(afour,bfour), bfour)

    it 'should handle deletion', ->
      afour = {
          a: 'a'
          b: 'a'
        }

      bfour = {
          a: 'a'
          b: 'b'
        }
      a = {
        one: 'hello'
        two: [1,2,3]
        three: 42
        four: afour
        five: 44
      }

      b = {
        one: 'hellop'
        two: [1,2,3,4]
        three: 43
        four: bfour
      }

      d = diff(a,b)

      changes = odiff.changes d, b

      expect(Object.keys(changes).length).eq 3
      expect(Object.keys(changes[1]).length).eq 3
      expect(Object.keys(changes[0]).length).eq 1
      expect(Object.keys(changes[0].four)).deep.eq ['1']
      expect(changes[0].four).deep.eq odiff.changes(diff(afour,bfour), bfour)
      expect(changes[-1].length).eq 1
      expect(changes[-1]).deep.eq ['five']



