Snapshots = require './snapshots'
Outlet = require '../cascade/outlet'
Cascade = require '../cascade/cascade'
Emitter = require '../events/emitter'
{include, extend} = require '../mixin'
debugCascade = global.debug 'ace:cascade'

class HistoryOutlets extends Snapshots
  include HistoryOutlets, Emitter
  @name = 'HistoryOutlets'

  class SyncOutlet extends Outlet
    set: (value, options) ->
      if typeof value is 'function' or (value instanceof Cascade and not (value instanceof SyncOutlet))
        @_noSync = true
      super

  class SlidingOutlet extends SyncOutlet
    @name = 'SlidingOutlet'

    constructor: (snapshots, path, @_syncValue) ->
      super @_syncValue

      @outflows.add @_out = =>
        if @_value != @_syncValue
          @_syncValue = @_value
          dataStore = snapshots.dataStore.array[snapshots.to['index']]
          dataStore.localPath(path)['_'] = @_value

    sync: (value) ->
      return if @pending or @_noSync or @_toOutlet?._noSync
      @_syncValue = value
      @set value

    slide: (outlet) ->
      return unless outlet != @_toOutlet
      @unset @_toOutlet if @_toOutlet
      @set outlet, silent: true if @_toOutlet = outlet
      return

  class ToHistoryOutlet extends SyncOutlet
    @name = 'ToHistoryOutlet'

    constructor: (@_slidingOutlet) ->
      @_slidingOutlet._toOutlet = this
      super @_slidingOutlet._value
      @_slidingOutlet.set this, silent: true

    localizeChanges: ->
      return if @_noSync
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

    get: (path) ->
      path = Snapshots.getPath path
      return current if (current = (base = @ensurePath(path))['_'])?
      outlet = base['_'] = new SlidingOutlet(@['_snapshots'], path, @['_snapshots'].dataStore.array[@['index']].get(path)?['_'])
      debugCascade "created #{outlet} at #{path.join('/')}"
      outlet

    slide: do ->
      empty = {}

      recurse = (o,to) ->
        to ||= empty
        recurse(v, to[k]) for k, v of o when k.charAt(0) != '_' and k isnt 'index' and !o.constructor.prototype[k]?
        o['_'].slide to if o.hasOwnProperty '_'
        return

      (index) ->
        @['index'] = index
        recurse(this, @['_snapshots'].to)

  class FromHistorySnapshot extends Snapshots.Snapshot
    constructor: (snapshots) ->
      @['_snapshots'] = snapshots
      @['index'] = -1

    _inherit: -> throw new Error()

    get: (path) ->
      path = Snapshots.getPath path
      @ensurePath(path)['_'] ?= new FromHistoryOutlet(if ~@['index'] then @['_snapshots'].dataStore.array[@['index']].get(path)?['-'] else undefined)

  class ToHistorySnapshot extends Snapshots.Snapshot
    constructor: (snapshots) ->
      @['_snapshots'] = snapshots
      @['index'] = 0
      super

    _inherit: ->
      ret = super
      ret['index'] = @['index'] + 1
      ret

    get: (path) ->
      path = Snapshots.getPath path
      return current if (current = (base = @ensurePath(path))['_'])?
      base[key] = new ToHistoryOutlet @['_snapshots'].sliding.get(path)

    set: (path, value) ->
      @get(path).set(value)
      return this

    # sets the path to null (NOT undefined) if it isn't own property
    noInherit: (path) ->
      path = Snapshots.getPath path
      @['_snapshots'].dataStore.array[@['index']].noInherit path
      (super path)?.localizeChanges()
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
