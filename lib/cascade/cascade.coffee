Outflows = require './outflows'
Emitter = require '../events/emitter'
addBlocks = require './blocks'
{include, extend} = require '../mixin'

class Cascade

  @id = do ->
    count = 0
    ->
      count = if count+1 == count then 0 else count+1
      "#{count}-Cascade"

  include Cascade, Emitter

  addBlocks(@)

  constructor: (@func) ->
    @func ||= ->
    @inflows = {}
    @changes = []
    @outflows = new Outflows(this, Cascade)
    @pending = new Pending(this)
    @cid = Cascade.id()

  class Pending
    constructor: (@cascade) ->
      @_pending = false
    get: -> @_pending
    set: (pending) ->
      return if !!pending == @_pending
      @_pending = !!pending
      if @_pending
        @cascade.outflows._setPending()
      return

  # remove inflow or all inflows
  detach: (inflow) ->
    unless inflow?
      inflows = @inflows
      inflow.outflows.removeAll this for cid,inflow of inflows
    else
      inflow.outflows?.removeAll this

    return
    
  run: (source) ->
    @pending.set(true)

    if Cascade.roots
      Cascade.roots.push unless source then this else (=> @_calculate(false,source))
    else
      @_calculate(false, source)
    return

  # optimization that should only be used internally when it's clear there is no Cascade.root
  _cascade: ->
    @pending.set(true)
    @pending.set(false)
    @outflows._calculate(false)
    return

  _calculateDone: (dry) ->
    if @_stopPropagation
      delete @_stopPropagation
      dry = true

    @pending.set(false)
    @outflows._calculate(dry)
    @calculating = false
    @changes = []

  _calculate: (dry, source) ->
    return unless @pending.get()

    @changes.push source if !dry and source and source.cid?

    for cid,inflow of @inflows when inflow.pending.get()
      if not @outflows[inflow.cid]?
        @_noDry = true if not dry # ie, calculate this anyway if another input is dry because at least 1 input is "wet"
        return

    @calculating = true
    @_calculateNum = (@_calculateNum || 0) + 1

    if @_noDry
      delete @_noDry
      dry = false

    if not @func.length
      @func() if not dry
      @_calculateDone(dry)
    else if dry
      @_calculateDone(dry)
    else
      num = @_calculateNum
      @func =>
        return if num != @_calculateNum
        @_calculateDone(dry)

    return

  # can be called by the func to prevent updating outflows
  stopPropagation: ->
    @_stopPropagation = true


module.exports = Cascade
