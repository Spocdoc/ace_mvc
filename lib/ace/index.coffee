Routing = require './routing'
Outlet = require '../snapshots/outlet'
HistoryOutlets = require '../snapshots/history_outlets'
Variable = require './variable'
View = require '../mvc/view'
Template = require '../mvc/template'

class Ace
  constructor: (@historyOutlets = new HistoryOutlets) ->
    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) => new Variable @historyOutlets, path, fn

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



  push: ->
    @historyOutlets.navigate()
    @routing.push()

  appendTo: ($container) ->



module.exports = Ace
