Snapshots = require './snapshots'
Outlet = require '../cascade/outlet'
Cascade = require '../cascade/cascade'
Emitter = require '../events/emitter'
{include, extend} = require '../mixin'

class HistoryOutlets extends Snapshots
  include HistoryOutlets, Emitter

  class @ToHistoryOutlet extends Outlet
    constructor: (snapshots, path, key, @_syncValue) ->
      super @_syncValue
      @outflows.add @_out = =>
        if @_value != @_syncValue
          @_syncValue = @_value
          dataStore = snapshots.dataStore[snapshots.to.index]
          dataStore.localPath(path)[key] = @_value

    sync: (value) ->
      @_syncValue = value
      @set value

    localizeChanges: ->
      prevValue = @_syncValue
      @_out()
      @_syncValue = @_value = prevValue
      return

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
      current = (base = @ensurePath(path))[key]
      return current if current?
      base[key] = outlet = new @_snapshots.historyOutletFactory(@_snapshots, path, key, @_snapshots.dataStore[@index].get(path)?[key])
      @_snapshots.emit 'newOutlet', path, key, outlet
      outlet

    # sets the path to null (NOT undefined) if it isn't own property
    noInherit: (path, key) ->
      [path..., key] = path if not key?
      @_snapshots.dataStore[@index].noInherit path, key
      @each path.concat(key), (outlet) -> outlet.localizeChanges()
      super(path,key)

  constructor: (@dataStore = new Snapshots) ->
    # when constructing, don't want to push to dataStore again
    @push = push = => HistoryOutlets.__super__.push.apply(this, arguments)
    super
    delete @push

    @to = @[0]
    @from = new FromHistorySnapshot this

    `var len = this.dataStore.length, i;
    for (i=1; i < len; ++i) push();`

    # proxy all the methods of .to to avoid common bugs
    for name,fn of @to when typeof fn is 'function' && !@[name]?
      @[name] = do (fn) => => fn.apply(@to, arguments)

  snapshotFactory: => new ToHistorySnapshot(this)

  historyOutletFactory: @ToHistoryOutlet

  push: ->
    return super if arguments.length
    @dataStore.push()
    super

  splice: ->
    super
    @dataStore.splice.apply(@dataStore, arguments)

  navigate: (index) ->
    # run outside the (possible) current block so changes take effect before
    # moving the bindings
    Cascade.Unblock => @emit 'willNavigate'

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

    @emit 'didNavigate'
    return

module.exports = HistoryOutlets

# add OJSON serialization functions
require('./history_outlets_ojson')(HistoryOutlets)
