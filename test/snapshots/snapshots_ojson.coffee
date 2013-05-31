Snapshots = lib 'snapshots'
OJSON = lib '../ojson'
snapshotTests = require './_snapshot_tests'

describe 'Snapshots_OJSON', ->
  it 'should serialize', ->
    @a = new Snapshots
    @a.array[0].ensurePath(['foo','bar'])['baz'] = 'hello world'
    str = OJSON.stringify @a
    expect(typeof str).eq 'string'
    expect(str.length).gt 0

  it 'should restore simple cases', ->
    @a = new Snapshots
    @a.array[0].ensurePath(['foo','bar'])['baz'] = 'hello world'
    str = OJSON.stringify @a

    expect(@a.array[0]['foo']['bar']['baz']).eq 'hello world'
    @a = OJSON.parse str
    expect(@a.array[0]['foo']['bar']['baz']).eq 'hello world'

  it 'should restore inheritance', ->
    @a = new Snapshots
    @a.array[0].ensurePath(['foo','bar'])['baz'] = 'hello world'
    @a.push()
    @a.array[1].ensurePath(['foo','bar'])['mo'] = 'curl'
    @a.array[1].localPath(['foo','baz'])['mo'] = 'curl'
    @a = OJSON.parse OJSON.stringify @a
    expect(@a.array[0]['foo']['bar']['mo']).eq 'curl'
    expect(@a.array[1]['foo']['bar']['mo']).eq 'curl'
    expect(@a.array[0]['foo']['baz']).not.exist
    expect(@a.array[1]['foo']['baz']['mo']).eq 'curl'

  it 'should produce the same result when serialized multiple times', ->
    @a = new Snapshots
    @a.array[0].ensurePath(['foo','bar'])['baz'] = 'hello world'
    @a.push()
    @a.array[1].ensurePath(['foo','bar'])['mo'] = 'curl'
    @a.array[1].localPath(['foo','baz'])['mo'] = 'curl'

    strs = (OJSON.stringify @a for i in [1..5])
    expect(str).eq strs[0] for str in strs

  describe 'Snapshot tests', ->
    snapshotTests Snapshots,
      thruJSON: (obj) -> OJSON.parse OJSON.stringify obj

