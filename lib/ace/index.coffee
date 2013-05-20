Routing = require './routing'
Outlet = require '../cascade/outlet'
HistoryOutlets = require '../snapshots/history_outlets'
Variable = require './variable'
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
        path = Ace.makeOutletPath this, name
        hdOutlet = ace.historyOutlets.to.get(path)
        outlet = new Outlet(hdOutlet.get())
        console.log "created outlet #{outlet.cid} at",path.join('/'), "with hd",hdOutlet.cid
        hdOutlet.set(outlet)
        outlet

      newFromOutlet: (name) ->
        path = Ace.makeOutletPath this, name
        console.log "created FROM outlet at ",path.join('/')
        hdOutlet = ace.historyOutlets.from.get(path)
        outlet = new Outlet(hdOutlet.get())
        hdOutlet.sets(outlet)
        outlet

      newController: (type, name, settings) ->
        new ace.Controller(type, this, name, settings)

    extend @, Base

    @root = @newOutlet('root')
    @rootType = @newOutlet('rootType')
    @rootType.set('root') unless @rootType.get()

    @rootType.outflows.add =>
      type = @rootType.get()
      return if (root = @root.get())?.type == type
      @historyOutlets.noInherit(@path)
      root?.remove()
      @root.set(@newController(type))
      @appendTo(@$container) if @$container
      return

    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) => new Variable @historyOutlets, path, fn

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

  appendTo: (@$container) ->
    unless @root.get()
      @rootType.run()
    else
      @root.get().appendTo($container)
    return

module.exports = Ace
