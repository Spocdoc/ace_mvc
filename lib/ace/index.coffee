Routing = require './routing'
Outlet = require '../cascade/outlet'
HistoryOutlets = require '../snapshots/history_outlets'
View = require '../mvc/view'
Controller = require '../mvc/controller'
Template = require '../mvc/template'
Db = require '../db/db'
Model = require '../mvc/model'
Statelet = require '../cascade/statelet'
{include,extend} = require '../mixin'

class Ace

  @makeOutletPath = (inst, name) ->
    path = inst.path.concat()
    switch inst.constructor.name
      when 'View' then name = "$#{name}"
      when 'Ace'
        name = "#{path[0]}-#{name}"
        path = []
    path.push name
    path
    
  constructor: (@historyOutlets = new HistoryOutlets, @name='') ->
    @path = [@name]

    ace = this

    Base =
      newOutlet: (name) ->
        outlet = ace.historyOutlets.to.get path = Ace.makeOutletPath(this, name)
        # console.log "created outlet #{outlet.cid} at",path.join('/'),"with value",outlet.get()
        outlet

      newSlidingOutlet: (name) ->
        outlet = ace.historyOutlets.sliding.get path = Ace.makeOutletPath(this, name)
        # console.log "created sliding outlet #{outlet.cid} at",path.join('/'),"with value",outlet.get()
        outlet

      newFromOutlet: (name) ->
        outlet = ace.historyOutlets.from.get path = Ace.makeOutletPath(this, name)
        # console.log "created outlet #{outlet.cid} at",path.join('/')
        outlet

      newController: (type, name, settings) ->
        new ace.Controller(type, this, name, settings)

      to: (path) -> ace.historyOutlets.to.value(path)
      from: (path) -> ace.historyOutlets.from.value(path)
      local: (path) -> ace.historyOutlets.noInherit(path)

    extend @, Base

    @root = @newOutlet('root')
    @rootType = @newOutlet('rootType')
    @rootType.set('root') unless @rootType.get()

    @rootType.outflows.add => @_setRoot()

    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) =>
        outlet = @historyOutlets.sliding.get path
        outlet.set fn
        outlet

    @constructor.db ||= new Db

    class @Template extends Template
      _build: (base) ->
        @ace = ace
        return super unless @$root = ace.$container?.find("##{@prefix}")
        @$['root'] = @$root
        for id in base.ids
          (@["$#{id}"] = @$[id] = @$root.find("##{@prefix}-#{id}"))
            .template = this
        return

    class @View extends View
      include @, Base

      constructor: ->
        @ace = ace
        super

      newStatelet: (name) ->
        Ace.makeOutletPath this, name
        hdOutlet = ace.historyOutlets.to.get(path)
        statelet = new Statelet undefined,
          value: hdOutlet.get()
          enableSet: @inWindow
        hdOutlet.set(statelet)

        ace.routing.navigator?.on 'willNavigate', -> statelet.run()
        statelet

      newTemplate: (type) ->
        new ace.Template(type, this)

      navigate: -> ace.routing.navigate()

    class @Model extends Model
      constructor: (coll, idOrSpec) ->
        super coll, ace.constructor.db, idOrSpec

    class @Controller extends Controller
      include @, Base

      newView: (type, name, settings) ->
        new ace.View(type, this, name, settings)

      newModel: (type, idOrSpec) -> new ace.Model(type, idOrSpec)

      navigate: -> ace.routing.navigate()

  _setRoot: ->
    type = @rootType.get()
    return if (root = @root.get())?.type == type
    @historyOutlets.noInherit(@path)
    root?.remove()
    @root.set(@newController(type))
    @appendTo(@$container) if @$container
    return

  appendTo: (@$container) ->
    unless @root.get()
      @_setRoot()
    else
      @root.get().appendTo($container)
    return

module.exports = Ace
