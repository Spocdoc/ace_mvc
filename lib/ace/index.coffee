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

  constructor: (@name='ace', @historyOutlets = new HistoryOutlets) ->
    @path = [@name]

    ace = this

    Base =
      newOutlet: (name) ->
        console.log "created outlet at ",@path.concat(@constructor.name)," with ",name
        hdOutlet = ace.historyOutlets.to.get(@path.concat(@constructor.name), name)
        outlet = new Outlet(hdOutlet.get())
        hdOutlet.set(outlet)
        outlet

      newFromOutlet: (name) ->
        hdOutlet = ace.historyOutlets.from.get(@path.concat(@constructor.name), name)
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
      @historyOutlets.noInherit(@path.concat('Controller'))
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
        hdOutlet = ace.historyOutlets.to.get(@path.concat('view'), name)
        statelet = new Statelet undefined,
          value: hdOutlet.get()
          enableSet: @inWindow
        hdOutlet.set(statelet)

        ace.routing.navigator?.on 'willNavigate', -> statelet.run()
        statelet

      newTemplate: (type) ->
        new ace.Template(type, this)

    class @Model extends Model
      constructor: (coll, idOrSpec) ->
        super coll, ace.constructor.db, idOrSpec

    class @Controller extends Controller
      include @, Base

      constructor: ->
        console.log "YAY ace controller"
        super

      newView: (type, name, settings) ->
        new ace.View(type, this, name, settings)

      newModel: (type, idOrSpec) -> new ace.Model(type, idOrSpec)

  push: ->
    @historyOutlets.navigate()
    @routing.push()

  appendTo: (@$container) ->
    unless @root.get()
      @rootType.run()
    else
      @root.get().appendTo($container)
    return

module.exports = Ace
