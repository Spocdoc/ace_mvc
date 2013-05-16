Routing = require './routing'
Outlet = require '../cascade/outlet'
HistoryOutlets = require '../snapshots/history_outlets'
Variable = require './variable'
View = require '../mvc/view'
Template = require '../mvc/template'
Db = require '../db/db'
Model = require './model'

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
        for id in base.ids
          (@["$#{id}"] = @$[id] = @$root.find("##{@prefix}-#{id}"))
            .template = this
        return

    class @View extends View
      constructor: ->
        @ace = ace
        super

      _Outlet: (name, init) ->
        hdOutlet = ace.historyOutlets.to.get(@path, name)
        outlet = new Outlet(hd.get() || init)
        hdOutlet.set(outlet)
        outlet

      _Statelet: (name) ->
        outlet = new @_Outlet(name)
        ace.routing.navigator?.on 'willNavigate', -> outlet.run()
        outlet

      _Template: (name) ->
        new ace.Template[name](this)

    class @Model extends Model
      constructor: (coll, idOrSpec) ->
        super ace.constructor.db, coll, idOrSpec


  # _setupDb: ->
  #   @db = new Db

  #   # save & restore outflows on navigation

  #   dbOutflows = []
  #   @historyOutlets.on 'willNavigate', =>
  #     for name, coll of @db.collections
  #       for id, model of coll.models
  #         for outlet in model.outlets
  #           @historyOutlets.get(['db','outflows']).set(





  push: ->
    @historyOutlets.navigate()
    @routing.push()

  appendTo: ($container) ->



module.exports = Ace
