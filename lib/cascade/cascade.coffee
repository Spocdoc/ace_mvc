Outflows = require './outflows'
Emitter = require '../utils/events/emitter'
addBlocks = require './blocks'
{include, extend} = require '../utils/mixin'
makeId = require '../utils/id'
debug = global.debug 'ace:cascade'
debugCount = global.debug 'ace:cascade:count'

module.exports = ->
  class Cascade
    extend Cascade, Emitter
    @pending = 0

    constructor: (@func) ->
      @func ||= ->
      @inflows = {}
      @changes = []
      @outflows = new Outflows(this, Cascade)
      @pending = false
      @_runNumber = 0
      @cid = makeId()

    @run: (cascade, source) ->
      if typeof cascade is 'function'
        cascade(source)
      else
        cascade._run(source)
      
    run: (source) ->
      sp = source?.pending
      debug "called run on #{@}"
      @setThisPending true
      @outflows.setPending true
      @_mustRun = true # must run at least once since explicitly asked it to
      @constructor.run this, source unless sp
      return

    allOutflows: (hash) ->
      for outflow in @outflows.array when !hash[outflow.cid]
        hash[outflow.cid] = outflow
        outflow.allOutflows? hash
      hash

    cascade: ->
      debug "called cascade on #{@}"
      @setThisPending false
      unless @running
        # this is to stop recursion if this is an outflow of one of its outflows
        @outflows.setPending @pending = true
        @pending = false
      # explicit looping because the array length could change while looping it
      outflow._mustRun = true for outflow in @outflows.array
      `for (var i = 0, arr = this.outflows.array; i < arr.length; ++i) {
        outflow = arr[i];
        if (outflow.pending || outflow.pending === (void 0)) {
          this.constructor.run(outflow, this);
        }
      }`
      return

    setThisPending: (tf) ->
      return if @pending is tf=!!tf
      debug "set pending [#{tf}] on #{@}"
      @pending = tf
      debugCount "#{if tf then "+1" else "-1"} from #{Cascade.pending}"
      unless (Cascade.pending += if tf then 1 else -1)
        debugCount "done"
        Cascade.emit 'done'
      return

    setPending: (tf) ->
      return if @pending is tf=!!tf

      if !tf
        return unless @_canRun()
        return @constructor.run this if @_mustRun

      @setThisPending tf
      @outflows.setPending tf
      return

    _canRun: ->
      for cid,inflow of @inflows when inflow.pending
        return false unless @outflows[inflow.cid]?
      true

    _run: do ->
      done = (cascade) ->
        cascade.changes = []

        if cascade._stopPropagation
          debug "#{cascade} called stopPropagation"
          cascade._stopPropagation = false
          cascade.setPending(false)
        else
          cascade.cascade()

        cascade.running = false
        return


      (source) ->
        unless @pending
          debug "not running #{@} because not pending mustrun: [#{@_mustRun}]"
          return

        @changes.push source if source

        unless @_canRun()
          debug "can't run #{source}->#{@} yet because pending inflows"
          @_mustRun = true
          return

        @_mustRun = false

        @running = true
        ++@_runNumber

        if @func.length
          num = @_runNumber
          @func =>
            return if num != @_runNumber
            done this
        else
          @func()
          done this
        return

    # can be called by the func to prevent updating outflows
    stopPropagation: ->
      @_stopPropagation = true

  addBlocks Cascade
  Cascade

