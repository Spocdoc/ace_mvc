HistoryOutlets = lib 'history_outlets'
Snapshots = lib 'snapshots'
OJSON = lib '../ojson'

thruJSON = (obj) ->
  OJSON.parse OJSON.stringify OJSON.parse OJSON.stringify obj

describe 'HistoryOutlets_OJSON', ->
  it 'should restore with the same number of entries as the dataStore', ->
    @a = new HistoryOutlets
    @a.navigate()
    @a = thruJSON @a
    expect(@a.length).eq 2
    expect(@a.dataStore.length).eq 2

  it 'should restore at the 0 index', ->
    @a = new HistoryOutlets
    @a.navigate()
    @a = thruJSON @a
    expect(@a.to['index']).eq 0

  it 'should restore the dataStore entries (although not the outlets)', ->
    @a = new HistoryOutlets
    @a.to.get(['foo','bar']).set(42)
    @a.to.get(['foo','baz']).set(43)
    @a.navigate()
    @a.to.noInherit(['foo','bar'])
    @a.to.get(['foo','bar']).set(44)

    ds = @a.dataStore

    @a = thruJSON @a

    # the outlets are not restored. have to be re-created
    @a.to.get(['foo','bar'])
    @a.to.get(['foo','baz'])

    expect(@a.to['foo']['bar'].get()).eq 42
    expect(@a.to['foo']['baz'].get()).eq 43
    @a.navigate(1)
    expect(@a.to['foo']['bar'].get()).eq 44
