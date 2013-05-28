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
debugCascade = global.debug 'ace:cascade'

commonMethods =
  newOutlet: (name) ->
    outlet = @ace.historyOutlets.to.get path = Ace.makeOutletPath(this, name)
    debugCascade "created #{outlet} at",path.join('/')
    outlet

  newSlidingOutlet: (name) ->
    outlet = @ace.historyOutlets.sliding.get path = Ace.makeOutletPath(this, name)
    debugCascade "created #{outlet} at",path.join('/')
    outlet

  newFromOutlet: (name) ->
    outlet = @ace.historyOutlets.from.get path = Ace.makeOutletPath(this, name)
    debugCascade "created #{outlet} at",path.join('/')
    outlet

  newController: (type, name, settings) ->
    debugCascade "creating new controller",type,name
    new Ace.Controller(@ace,type, this, name, settings)

  to: (path) -> @ace.historyOutlets.sliding.get(path).get()
  from: (path) -> @ace.historyOutlets.from.get(path).get()
  local: (path) -> @ace.historyOutlets.noInherit(path)

class Ace

  @newClient: (historyOutletsOJSON, routesObj, $container) ->
    global['ace'] = new Ace(OJSON.fromOJSON(historyOutletsOJSON))
    ace.routing.enable routesObj
    navigator = ace.routing.enableNavigator()
    ace.routing.router.route navigator.url
    ace.appendTo $container
    return

  @makeOutletPath = (inst, name) ->
    path = inst.path.concat()
    switch inst.constructor
      when Ace.View, View then name = "$#{name}"
      when Ace
        name = "#{path[0]}-#{name}"
        path = []
    path.push name
    path
    
  class @Template extends Template
    @_bootstrapped = {} # re-used element ids from the server-rendered dom

    constructor: (@ace, others...) ->
      super others...

    _build: (base) ->
      boot = @constructor._bootstrapped
      return super unless !boot[@prefix] && (@$root = @ace.$container?.find("##{@prefix}")).length
      boot[@prefix] = true
      @$['root'] = @$root
      for id in base.ids
        (@["$#{id}"] = @$[id] = @$root.find("##{@prefix}-#{id}"))
          .template = this
      return

  class @View extends View
    include @, commonMethods

    constructor: (@ace, others...) -> super others...

    newStatelet: (name) ->
      Ace.makeOutletPath this, name
      hdOutlet = @ace.historyOutlets.to.get(path)
      statelet = new Statelet undefined,
        value: hdOutlet.get()
        enableSet: @inWindow
      hdOutlet.set(statelet)

      @ace.routing.navigator?.on 'willNavigate', -> statelet.run()
      statelet

    newTemplate: (type) ->
      new Ace.Template(@ace, type, this)

    navigate: -> @ace.routing.navigate()

  class @Model extends Model
    constructor: (@ace, coll, idOrSpec) ->
      super coll, @ace.constructor.db, idOrSpec

  class @Controller extends Controller
    include @, commonMethods

    constructor: (@ace, others...) -> super others...

    newView: (type, name, settings) ->
      new Ace.View(@ace, type, this, name, settings)

    newModel: (type, idOrSpec) -> new Ace.Model(@ace, type, idOrSpec)

    navigate: -> @ace.routing.navigate()

  constructor: (@historyOutlets = new HistoryOutlets, @name='') ->
    @path = [@name]
    @ace = this

    extend @, commonMethods

    @root = @newOutlet('root')
    @rootType = @newOutlet('rootType')
    @rootType.set('body') unless @rootType.get()

    @rootType.outflows.add => @_setRoot()

    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) =>
        outlet = @historyOutlets.sliding.get path
        outlet.set fn
        outlet

    @constructor.db ||= new Db

  toString: -> "Ace [#{@name}]"

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
