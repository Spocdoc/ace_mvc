Outflows = require './outflows'
Emitter = require '../events/emitter'
addBlocks = require './blocks'
{include, extend} = require '../mixin'
makeId = require '../id'
debug = global.debug 'ace:cascade'

class Cascade
  include Cascade, Emitter

  constructor: (@func) ->
    @func ||= ->
    @inflows = {}
    @changes = []
    @outflows = new Outflows(this, Cascade)
    @pending = false
    @_runNumber = 0
    @cid = makeId()

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
    @outflows.setPending @pending = true
    @_mustRun = true # must run at least once since explicitly asked it to
    Cascade.run this, source unless sp
    return

  cascade: ->
    debug "called cascade on #{@}"
    unless @running
      # this is to stop recursion if this is an outflow of one of its outflows
      @outflows.setPending @pending = true
      @pending = false
    Cascade.run outflow, this for outflow in @outflows
    return

  setPending: (tf) ->
    return if @pending is tf=!!tf

    if !tf
      return unless @_canRun()
      return Cascade.run this if @_mustRun

    debug "set pending [#{tf}] on #{@}"

    @pending = tf
    @outflows.setPending tf
    return

  _canRun: ->
    for cid,inflow of @inflows when inflow.pending
      return false unless @outflows[inflow.cid]?
    true

  _run: do ->
    done = (cascade) ->
      if cascade._stopPropagation
        debug "#{cascade} called stopPropagation"
        cascade._stopPropagation = false
        cascade.setPending(false)
      else
        cascade.pending = false
        cascade.cascade()
      cascade.running = false
      cascade.changes = []

    (source) ->
      unless @pending
        debug "not running #{@} because not pending"
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
module.exports = Cascade


