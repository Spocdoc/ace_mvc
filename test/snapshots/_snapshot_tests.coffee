Snapshots = require '../../lib/snapshots/snapshots'
OJSON = require '../../lib/ojson'

module.exports = snapshotTests = (clazz, options) ->
  thruJSON = options?.thruJSON || (obj) -> obj

  beforeEach ->
    @a = new clazz

  it 'should begin with 1 entry', ->
    expect(@a.array.length).eq 1

  it 'should inherit values in push', ->
    @a = thruJSON @a
    expect(@a.push()).eq 2
    expect(@a.array.length).eq 2
    @a.array[0]['foo'] = 'bar'
    @a = thruJSON @a
    expect(@a.array[1]['foo']).eq 'bar'
    @a.array[0]['foo'] = 'baz'
    @a = thruJSON @a
    expect(@a.array[1]['foo']).eq 'baz'

  it 'should not inherit in reverse', ->
    @a.push()
    @a.array[1]['foo'] = 'bar'
    @a = thruJSON @a
    expect(@a.array[1]['foo']).eq 'bar'
    expect(@a.array[0]['foo']).not.exist

  describe '#ensurePath', ->
    it 'should construct the necessary path', ->
      @a.array[0].ensurePath(['foo','bar'])
      @a = thruJSON @a
      expect(@a.array[0]['foo']['bar']).exist

    it 'should return an object at the given path', ->
      o = @a.array[0].ensurePath(['foo','bar'])
      o['baz'] = 'bo'
      @a = thruJSON @a
      expect(@a.array[0]['foo']['bar']['baz']).eq 'bo'

    it 'should return the top level object if passed empty array', ->
      o = @a.array[0].ensurePath([])
      o['baz'] = 'bo'
      @a = thruJSON @a
      expect(@a.array[0]['baz']).eq 'bo'

    it 'should only build the parts that aren\'t local or inherited', ->
      @a.array[0].ensurePath(['foo'])['bar'] = 'baz'
      @a.push()
      @a.array[1].ensurePath(['foo','mo'])['bo'] = 'ho'
      @a = thruJSON @a
      expect(@a.array[1]['foo']['bar']).eq 'baz'
      expect(@a.array[1]['foo']['mo']['bo']).eq 'ho'
      expect(@a.array[0]['foo']['mo']['bo']).eq 'ho'

  describe '#localPath', ->
    it 'should construct the necessary path', ->
      @a.array[0].localPath(['foo','bar'])
      @a = thruJSON @a
      expect(@a.array[0]['foo']['bar']).exist

    it 'should return an object at the given path', ->
      o = @a.array[0].localPath(['foo','bar'])
      o['baz'] = 'bo'
      @a = thruJSON @a
      expect(@a.array[0]['foo']['bar']['baz']).eq 'bo'

    it 'should return the top level object if passed empty array', ->
      o = @a.array[0].localPath([])
      o['baz'] = 'bo'
      @a = thruJSON @a
      expect(@a.array[0]['baz']).eq 'bo'

    it 'should ensure that keys added are always local, not in parent', ->
      @a.push()
      @a.array[1].localPath(['foo'])['bar'] = 'baz'
      @a = thruJSON @a
      expect(@a.array[1]['foo']['bar']).eq 'baz'
      expect(@a.array[0]['foo']).not.exist

    it 'should ensure that keys added are always local, not in parent, but when nested, outer container inherits', ->
      @a.array[0].ensurePath(['foo','bar'])['baz'] = 'bo'
      @a.push()
      @a.array[1].localPath(['foo','bar','ho'])['no'] = 'yo'
      @a = thruJSON @a
      expect(@a.array[0]['foo']['bar']['baz']).eq 'bo'
      expect(@a.array[1]['foo']['bar']['baz']).eq 'bo'
      expect(@a.array[0]['foo']['bar']['ho']).not.exist
      expect(@a.array[1]['foo']['bar']['ho']['no']).eq 'yo'

    it 'should inherit from parent container when identical path is created', ->
      @a.array[0].ensurePath(['foo','bar'])['baz'] = 'bo'
      @a.push()
      @a.array[1].localPath(['foo','bar'])['no'] = 'yo'
      @a = thruJSON @a
      expect(@a.array[0]['foo']['bar']['baz']).eq 'bo'
      expect(@a.array[1]['foo']['bar']['baz']).eq 'bo'
      expect(@a.array[0]['foo']['bar']['no']).not.exist
      expect(@a.array[1]['foo']['bar']['no']).eq 'yo'

  describe '#noInherit', ->
    it 'should prevent inheritance', ->
      if typeof @a.array[0].set is 'function'
        @a.array[0].set ['controller','delegate'], 42
      else
        @a.array[0].ensurePath(['controller']).delegate = 42
      @a.push()
      @a.array[1].noInherit(['controller','delegate'])
      expect(@a.array[1]['controller']['delegate']).not.exist
      @a = thruJSON @a
      expect(@a.array[1]['controller']['delegate']).not.exist

  describe '#syncTarget', ->
    beforeEach ->
      @a = new Snapshots # should always be Snapshots, even if testing HistoryOutlets
      @b = new clazz

      class @Leaf
        constructor: (@value) ->
        sync: (@value) ->

      OJSON.unregister 'Leaf'
      OJSON.register 'Leaf': @Leaf
      @Leaf.prototype.toJSON = -> @value

    it 'should set the keys of the target if and only if they exist', ->
      a = @a.array[0]
      b = @b.array[0]

      a.ensurePath([1,2,3])['foo'] = 'bar'
      a['alpha'] = 'bravo'
      a.ensurePath(['charlie'])['delta'] = 'echo'

      b.ensurePath(['charlie'])['delta'] = new @Leaf('zzzz')

      a = thruJSON a
      b = thruJSON b

      a.syncTarget b

      expect(b['charlie']['delta'].value).eq 'echo'
