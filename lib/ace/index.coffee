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
{include,extend,extendBound} = require '../mixin'

class Ace

  constructor: (@name='ace', @historyOutlets = new HistoryOutlets) ->
    @path = [@name]

    ace = this

    Base =
      Outlet: (name) ->
        hdOutlet = ace.historyOutlets.to.get(@path.concat(@constructor.name), name)
        outlet = new Outlet(hdOutlet.get())
        hdOutlet.set(outlet)
        outlet

      FromOutlet: (name) ->
        hdOutlet = ace.historyOutlets.from.get(@path.concat(@constructor.name), name)
        outlet = new Outlet(hdOutlet.get())
        hdOutlet.sets(outlet)
        outlet

    extendBound @, Base

    @root = new @Outlet('root')
    @rootType = new @Outlet('rootType')
    @rootType.set('root') unless @rootType.get()

    @rootType.outflows.add =>
      type = @rootType.get()
      return if (root = @root.get())?.type == type
      @historyOutlets.noInherit(@path.concat('Controller'))
      root?.remove()
      @root.set(new @Controller[type](this))
      @appendTo(@$container)
      return

    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) => new Variable @historyOutlets, path, fn

    @constructor.db ||= new Db

    class @Template extends Template
      _build: (base) ->
        @ace = ace
        return super unless @$root = ace.$container.find("##{@prefix}")
        @$['root'] = @$root
        for id in base.ids
          (@["$#{id}"] = @$[id] = @$root.find("##{@prefix}-#{id}"))
            .template = this
        return

    class @View extends View
      constructor: ->
        @ace = ace
        extendBound @, Base
        super

      Statelet: (name) =>
        hdOutlet = ace.historyOutlets.to.get(@path.concat('view'), name)
        statelet = new Statelet undefined,
          value: hdOutlet.get()
          enableSet: @inWindow
        hdOutlet.set(statelet)

        ace.routing.navigator?.on 'willNavigate', -> statelet.run()
        statelet

      Template: (name) =>
        new ace.Template[name](this)

    class @Model extends Model
      constructor: (coll, idOrSpec) ->
        super ace.constructor.db, coll, idOrSpec

    class @Controller extends Controller
      constructor: ->
        extendBound @, Base
        super

      View: (type, name, settings) =>
        new ace.View[type](this, name, settings)

      Model: (type, idOrSpec) => new ace.Model[type](idOrSpec)

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
