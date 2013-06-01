Outflows = require './outflows'
Emitter = require '../events/emitter'
addBlocks = require './blocks'
{include, extend} = require '../mixin'
makeId = require '../id'
debug = global.debug 'ace:cascade'
debugCount = global.debug 'ace:cascade:count'

class Cascade
  extend Cascade, Emitter

  constructor: (@func) ->
    @func ||= ->
    @inflows = {}
    @changes = []
    @outflows = new Outflows(this, Cascade)
    @pending = false
    @_runNumber = 0
    @cid = makeId()

  @newContext: ->
    @_emitter = {}
    @_emitter.pending = 0
    @_emitter

  # remove inflow or all inflows
  detach: (inflow) ->
    unless inflow?
      inflows = @inflows
      inflow.outflows.removeAll this for cid,inflow of inflows
    else
      inflow.outflows?.removeAll this

    return

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
    Cascade.run this, source unless sp
    return

  cascade: ->
    debug "called cascade on #{@}"
    unless @running
      @setThisPending false
      # this is to stop recursion if this is an outflow of one of its outflows
      @outflows.setPending @pending = true
      @pending = false
    for outflow in @outflows.array when outflow.pending in [undefined, true]
      outflow._mustRun = true # explicitly requested a cascade so must run even if there's a loop later
      Cascade.run outflow, this
    return

  setThisPending: (tf) ->
    return if @pending is tf=!!tf
    debug "set pending [#{tf}] on #{@}"
    @pending = tf
    if cc = Cascade._emitter
      debugCount "#{if tf then "+1" else "-1"} from #{cc.pending}"
      unless (cc.pending += if tf then 1 else -1)
        debugCount "done"
        Cascade.emit 'done'
    return

  setPending: (tf) ->
    return if @pending is tf=!!tf

    if !tf
      return unless @_canRun()
      return Cascade.run this if @_mustRun

    @setThisPending tf
    @outflows.setPending tf
    return

  _canRun: ->
    for cid,inflow of @inflows when inflow.pending
      return false unless @outflows[inflow.cid]?
    true

  _run: do ->
    done = (cascade) ->
      prev = Cascade._emitter
      Cascade._emitter = cascade._cc

      cascade.changes = []

      if cascade._stopPropagation
        debug "#{cascade} called stopPropagation"
        cascade._stopPropagation = false
        cascade.setPending(false)
      else
        cascade.setThisPending false
        cascade.cascade()

      cascade.running = false

      Cascade._emitter = prev
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
      @_cc = Cascade._emitter

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
module.exports = Cascade


