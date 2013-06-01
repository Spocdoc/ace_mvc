Snapshots = require './snapshots'
Outlet = require '../cascade/outlet'
Cascade = require '../cascade/cascade'
Emitter = require '../events/emitter'
{include, extend} = require '../mixin'
debugCascade = global.debug 'ace:cascade'

class HistoryOutlets extends Snapshots
  include HistoryOutlets, Emitter
  @name = 'HistoryOutlets'

  class SyncingOutlet extends Outlet
    @name = 'SyncingOutlet'
    constructor: (snapshots, path, key, @_syncValue) ->
      super @_syncValue

      @outflows.add @_out = =>
        if @_value != @_syncValue
          @_syncValue = @_value
          dataStore = snapshots.dataStore.array[snapshots.to['index']]
          dataStore.localPath(path)[key] = @_value

    sync: (value) ->
      return if @pending
      @_syncValue = value
      @set value

  class SlidingOutlet extends SyncingOutlet
    @name = 'SlidingOutlet'
    slide: (outlet) ->
      return unless outlet != @_toOutlet
      @unset @_toOutlet if @_toOutlet
      @set outlet, silent: true if @_toOutlet = outlet
      return

  class ToHistoryOutlet extends Outlet
    @name = 'ToHistoryOutlet'
    constructor: (@_slidingOutlet) ->
      @_slidingOutlet._toOutlet = this
      super @_slidingOutlet._value
      @_slidingOutlet.set this, silent: true

    localizeChanges: ->
      syncValue = @_slidingOutlet._syncValue
      @_slidingOutlet.slide()

      if syncValue != @_value
        @_slidingOutlet.set @_value
      else
        @_slidingOutlet.set undefined

      @set syncValue
      return

  class FromHistoryOutlet extends Outlet
    @name = 'FromHistoryOutlet'
    constructor: ->
      super
      @_set = @set
      @set = undefined

    sync: (value) ->
      @_set value

  class SlidingSnapshot extends Snapshots.Snapshot
    constructor: (snapshots) ->
      @['_snapshots'] = snapshots
      @['index'] = 0

    _inherit: -> throw new Error()

    get: (path, key) ->
      [path, key] = Snapshots.getPathKey path, key
      return current if (current = (base = @ensurePath(path))[key])?
      outlet = base[key] = new SlidingOutlet(@['_snapshots'], path, key, @['_snapshots'].dataStore.array[@['index']].get(path)?[key])
      debugCascade "created #{outlet} at #{path.concat(key).join('/')}"
      outlet

    slide: do ->
      empty = {}

      recurse = (o,to) ->
        to ||= empty
        for k, v of o when k.charAt(0) != '_' and k isnt 'index' and !o.constructor.prototype[k]?
          if v instanceof Snapshots.Compound
            recurse v, to[k]
          else
            v.slide to[k]
        return

      (index) ->
        @['index'] = index
        recurse(this, @['_snapshots'].to)

  class FromHistorySnapshot extends Snapshots.Snapshot
    constructor: (snapshots) ->
      @['_snapshots'] = snapshots
      @['index'] = -1

    _inherit: -> throw new Error()

    get: (path, key) ->
      [path, key] = Snapshots.getPathKey path, key
      @ensurePath(path)[key] ?= new FromHistoryOutlet(if ~@['index'] then @['_snapshots'].dataStore.array[@['index']].get(path)?[key] else undefined)

  class ToHistorySnapshot extends Snapshots.Snapshot
    constructor: (snapshots) ->
      @['_snapshots'] = snapshots
      @['index'] = 0
      super

    _inherit: ->
      ret = super
      ret['index'] = @['index'] + 1
      ret

    get: (path, key) ->
      [path, key] = Snapshots.getPathKey path, key
      return current if (current = (base = @ensurePath(path))[key])?
      base[key] = new ToHistoryOutlet @['_snapshots'].sliding.get(path, key)

    set: (path, value) ->
      @get(path).set(value)
      return this

    # sets the path to null (NOT undefined) if it isn't own property
    noInherit: (path, key) ->
      [path, key] = Snapshots.getPathKey path, key
      @['_snapshots'].dataStore.array[@['index']].noInherit path, key
      return unless prev = super path,key
      if prev instanceof Snapshots.Compound
        Snapshots.Snapshot.each prev, (outlet) -> outlet.localizeChanges()
      else
        prev.localizeChanges()
      return

  constructor: (@dataStore = new Snapshots) ->
    # when constructing, don't want to push to dataStore again
    @push = push = => HistoryOutlets.__super__.push.apply(this, arguments)
    super()
    delete @push

    @to = @array[0]
    @from = new FromHistorySnapshot this
    @sliding = new SlidingSnapshot this

    `var len = this.dataStore.array.length, i;
    for (i=1; i < len; ++i) push();`

    # proxy all the methods of .to to avoid common bugs
    for name,fn of @to when typeof fn is 'function' && !@[name]?
      @[name] = do (fn) => => fn.apply(@to, arguments)

  snapshotFactory: => new ToHistorySnapshot(this)

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
      @from['index'] = @to['index']
      @dataStore.array[@to['index']].syncTarget @from

      if not index?
        @splice(@to['index']+1)
        @to = @array[@push()-1]
      else
        @to = @array[index]
        @sliding.slide index
        @dataStore.array[index].syncTarget @sliding
      return

    @emit 'didNavigate'
    return

module.exports = HistoryOutlets

# add OJSON serialization functions
require('./history_outlets_ojson')(HistoryOutlets)
