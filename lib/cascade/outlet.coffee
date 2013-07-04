_ = require '../utils/u'
makeId = require '../utils/id'
debug = global.debug 'ace:cascade'
debugError = global.debug 'ace:error'

module.exports = (Cascade) ->

  class Dir
    constructor: (@name) ->
      @length = 0
      @obj = {}

    push: (dir) ->
      @obj[dir.name] = dir
      @[@length++] = dir
      @length


  class OutletFunc
    constructor: (@outlet, @func, names) ->
      @autoInflows = {}
      @names = names && names.concat() || _.argNames(func)
      @names.pop() if @async = @names[@names.length-1] is 'done'

      context = @outlet.context

      if @length = @names.length
        outlets = []
        args = []
        for name,i in @names
          (outlets[i] = context.outlets[name]).outflows.add @outlet

      @_runBlock = new Cascade.Block =>
        done = @_done # because Cascade.Block can't take parameters

        prev = Outlet.auto
        if @outlet.auto
          Outlet.auto = @outlet
          @autoInflows[k] = 0 for k of @autoInflows
        else
          Outlet.auto = null

        try
          if @async
            done.call = false
            num = @outlet._runNumber
            next = (value) =>
              @outlet._setValue value if num is @outlet._runNumber
              done.call = true
              done() if done.returned
              return

            if @length
              args[i] = a.value for a,i in outlets
              args[i] = next
              result = @func.apply(context, args)
            else
              @func.call context, next

          else

            if @length
              args[i] = a.value for a,i in outlets
              @outlet._setValue @func.apply(context, args)
            else
              @outlet._setValue @func.call context

          if @outlet.auto
            for k,v of @autoInflows when !v
              debug "Removing auto inflow #{k} from #{@}"
              @outlet.inflows[k].outflows.remove @outlet
              delete @autoInflows[k]

        catch _error
          debugError _error.stack if _error
        finally
          Outlet.auto = prev

    run: (done) ->
      @_done = done
      @_runBlock()

    shouldRun: (changes) ->
      for change in @outlet.changes
        return true if change is @func or @autoInflows[change.cid]
      false

    detach: ->

    addAuto: (inflow) ->
      debug "Adding auto inflow #{inflow} to #{@outlet}"
      if @autoInflows[inflow.cid]?
        @autoInflows[inflow.cid] = 1
      else
        @autoInflows[inflow.cid] = 1

        inflow.outflows.add @outlet

        if inflow.pending and !@outlet.outflows[inflow.cid]
          debug "Aborting addAuto because new pending inflow for #{@outlet}"
          # then shouldn't run -- keep this pending but set @running to false
          ++@_runNumber
          @running = false
          throw 0

      return

  # options:
  #     silent    don't run the function immediately
  #     value     initialize the value (eg, if the value parameter is a function; used with silent)
  class Outlet extends Cascade
    @name = 'Outlet'
    @auto = undefined

    @root = new Dir

    @addDir: (path, outlet) ->
      dir = @root
      for p in path.split '/' when p
        unless e = dir.obj[p]
          dir.push e = new Dir p
        dir = e
      dir.outlet = outlet
      dir

    constructor: (init, options={}) ->
      @outlets = {}
      @version = 0
      @auto = !!options.auto
      @context = options.context

      super (done) =>
        debug "#{@changes[0]?.constructor.name} [#{@changes[0]?.cid}] -> #{@constructor.name} [#{@cid}]"

        done.call = true
        done.returned = false

        if @outletFunc?.shouldRun @changes
          found = @outletFunc
        else
          for change in @changes
            break if found = @outlets[change.cid]
          found ||= @outletFunc

        if found
          if found is @outletFunc
            found.run done
          else
            @_setValue found.value, found.version
        else
          @stopPropagation()

        done.returned = true
        done() if done.call
        return

      options.init = true
      @set init, options

    get: ->
      Outlet.auto?.outletFunc.addAuto this
      
      if @value and len = arguments.length
        if @value.get?.length > 0
          return @value.get(arguments...)
        else if len is 1 and typeof @value is 'object'
          return @value[arguments[0]]

      @value

    set: (value, options={}) ->
      return if @value is value

      debug "set #{options.silent && "(silently)" || ""} #{@constructor.name} [#{@cid}] to [#{value}]"

      ++@_runNumber
      @running = false
      outflow = false

      if typeof value is 'function'
        throw new Error if @outletFunc # "Can't set an outlet to more than one function at a time"
        value.cid ||= makeId()
        options.context && @context = options.context
        @outletFunc = new OutletFunc this, value, options.names

      else if value instanceof Cascade
        value.cid ||= makeId()
        return if @outlets[value.cid]

        @outlets[value.cid] = value

        if typeof value.set is 'function'
          value.set this, silent: true
        else if value.outflows
          value.outflows.add this

        outflow = true

      else
        @_setValue value, 0

      unless options.silent
        if value is @value
          @cascade() unless options.init
        else if options.init
          @setThisPending true
          @_run value
        else
          @run value

      @outflows.add value if outflow
      return

    # call when the object value has been modified in place
    modified: do ->
      version = 0
      ->
        @version = ++version
        @cascade()
        return

    unset: (value) ->
      if value instanceof Cascade
        return unless @outlets[value.cid]
        delete @outlets[value.cid]
        @outflows.remove value
        value.unset? this

      else unless value?
        eqOutlets = @outlets
        @outlets = {}

        for cid,value of eqOutlets
          @outflows.remove value
          value.unset? this

      return

    cascade: ->
      prev = Outlet.auto; Outlet.auto = null
      Cascade.prototype.cascade.call this
      Outlet.auto = prev
      return

    setDir: (@dir) ->
      @set ou if ou = dir.outlet
      if ou = @value?.outlets
        ou[elem.name]?.setDir elem for elem in dir
      return

    unsetDir: ->
      @unset ou if ou = @dir.outlet
      if ou = @value?.outlets
        ou[elem.name]?.unsetDir elem for elem in @dir
      @dir = undefined
      return

    toJSON: -> @value

    toString: -> "#{@constructor.name}#{if @auto then "/auto" else ""} [#{@cid}] value [#{@value}]"

    # include array methods. note that all of these are preserved in closure compiler
    for method in ['length', 'join', 'concat', 'slice']
      @prototype[method] = do (method) -> ->
        Array.prototype[method].apply(@value, arguments)

    for method in ['push', 'pop', 'reverse', 'shift', 'unshift', 'splice', 'sort']
      @prototype[method] = do (method) -> ->
        ret = Array.prototype[method].apply(@value, arguments)
        @modified()
        ret

    inc: (delta) -> @set(@value + delta)

    _setValue: (value, version) ->
      debug "_setValue #{@} to [#{value}]"

      if value instanceof Cascade
        rv = value.get() # fetch the value first, so if it's pending, the calculation will abort before setting
        if value isnt @_eqOutlet
          num = @_runNumber
          @pending = false # this hackery is because outlet's set alters the run state to invalidate running functions, which isn't wanted here
          @unset @_eqOutlet if @_eqOutlet
          @set @_eqOutlet = value, silent: true
          @pending = @running = true
          @_runNumber = num
        value = rv

      if @value is value and (!version? or @version is version)
        @stopPropagation()
      else
        @version = version || 0

        if @value != value
          @oldValue = @value
          @value = value

          if @dir
            if ou = @oldValue?.outlets
              ou[elem.name]?.unsetDir elem for elem in @dir
            if ou = @value?.outlets
              ou[elem.name]?.setDir elem for elem in @dir

      return

