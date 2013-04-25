Snapshots = require './snapshots'
Outlet = require '../cascade/outlet'
Cascade = require '../cascade/cascade'

class HistoryOutlets extends Snapshots
  class @ToHistoryOutlet extends Outlet
    constructor: (snapshots, path, key, @_syncValue) ->
      super @_syncValue
      @outflows.add =>
        if @_value != @_syncValue
          @_syncValue = @_value
          dataStore = snapshots.dataStore[snapshots.to.index]
          dataStore.localPath(path)[key] = @_value

    sync: (value) ->
      @_syncValue = value
      @set value

  class FromHistoryOutlet extends Outlet
    constructor: ->
      super
      @_set = @set
      @set = undefined
      @sets = (value) =>
        if typeof value.set is 'function'
          @detach()
          @_sync = => value.set.call(value, @_value)
          @outflows.add @_sync
          @cascade()

    sync: (value) ->
      @_set value

  class FromHistorySnapshot extends Snapshots.Snapshot
    constructor: (@_snapshots) ->
      @index = -1

    _inherit: -> throw new Error("FromHistorySnapshot should never be inherited from")

    get: (path, key) ->
      [path..., key] = path if not key?
      @ensurePath(path)[key] ?= new FromHistoryOutlet(if ~@index then @_snapshots.dataStore[@index].get(path)?[key] else undefined)


  class ToHistorySnapshot extends Snapshots.Snapshot
    constructor: (@_snapshots) ->
      @index = 0

    _inherit: ->
      ret = super
      ret.index = @index + 1
      ret

    get: (path, key) ->
      [path..., key] = path if not key?
      @ensurePath(path)[key] ?= new @_snapshots.historyOutletFactory(@_snapshots, path, key, @_snapshots.dataStore[@index].get(path)?[key])

    # sets the path to undefined if it isn't own property
    noInherit: (path, key) ->
      @_snapshots.dataStore[@index].noInherit path, key
      super

  constructor: (@dataStore = new Snapshots) ->
    super
    @to = @[0]
    @from = new FromHistorySnapshot this

  snapshotFactory: => new ToHistorySnapshot(this)

  historyOutletFactory: @ToHistoryOutlet

  push: ->
    @dataStore.push()
    super

  splice: ->
    super
    @dataStore.splice.apply(@dataStore, arguments)

  navigate: (index) ->
    Cascade.Block =>
      @from.index = @to.index
      @dataStore[@to.index].syncTarget @from

      if not index?
        @splice(@to.index+1)
        @to = @[@push()-1]
      else
        @to = @[index]
        @dataStore[index].syncTarget @to
      return
    return

module.exports = HistoryOutlets
