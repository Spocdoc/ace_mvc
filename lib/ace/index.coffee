Routing = require './routing'
Outlet = require '../cascade/outlet'
HistoryOutlets = require '../snapshots/history_outlets'
Variable = require './variable'
View = require '../mvc/view'
Template = require '../mvc/template'
Db = require '../db/db'
Model = require './model'
Statelet = require '../cascade/statelet'

class Ace
  constructor: (@historyOutlets = new HistoryOutlets) ->
    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) => new Variable @historyOutlets, path, fn

    @constructor.db ||= new Db

    ace = this

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
        super

      _Outlet: (name) ->
        hdOutlet = ace.historyOutlets.to.get(@path.concat('view'), name)
        outlet = new Outlet(hdOutlet.get())
        hdOutlet.set(outlet)
        outlet

      FromOutlet: (name) ->
        hdOutlet = ace.historyOutlets.from.get(@path.concat('view'), name)
        outlet = new Outlet(hdOutlet.get())
        hdOutlet.set(outlet)
        outlet

      _Statelet: (name) ->
        hdOutlet = ace.historyOutlets.to.get(@path.concat('view'), name)
        statelet = new Statelet undefined,
          value: hdOutlet.get()
          enableSet: @inWindow
        hdOutlet.set(statelet)

        ace.routing.navigator?.on 'willNavigate', -> statelet.run()
        statelet

      _Template: (name) ->
        new ace.Template[name](this)

    class @Model extends Model
      constructor: (coll, idOrSpec) ->
        super ace.constructor.db, coll, idOrSpec

    class @Controller extends Controller


  push: ->
    @historyOutlets.navigate()
    @routing.push()

  appendTo: ($container) ->



module.exports = Ace
