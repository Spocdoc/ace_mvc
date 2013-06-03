Routing = require './routing'
HistoryOutlets = require '../snapshots/history_outlets'
View = require '../mvc/view'
Controller = require '../mvc/controller'
Template = require '../mvc/template'
Db = require '../db/db'
Model = require '../mvc/model'
Cookies = require '../cookies'
OJSON = require '../ojson'
{include,extend} = require '../mixin'
debugBoot = global.debug 'ace:boot:mvc'

class Ace
  publicMethods = require('./public_methods')(Ace)

  include @, publicMethods

  @newClient: (ojson, routesObj, $container) ->
    global['ace'] = (ojson && OJSON.fromOJSON ojson) || new Ace
    ace.cookies = new Cookies
    ace.routing.enable routesObj
    navigator = ace.routing.enableNavigator()
    ace.routing.router.route navigator.url
    ace.appendTo $container
    return

  class @Template extends Template
    @_bootstrapped = {} # re-used element ids from the server-rendered dom

    constructor: (@ace, others...) ->
      super others...

    _build: (base) ->
      boot = @constructor._bootstrapped
      prev = boot[@prefix]
      boot[@prefix] = true

      unless !prev && (@$root = @ace.$container?.find("##{@prefix}")).length
        debugBoot "Not bootstrapping template with prefix #{@prefix}"
        return super

      debugBoot "Bootstrapping template with prefix #{@prefix}"
      @$['root'] = @$root
      for id in base.ids
        (@["$#{id}"] = @$[id] = @$root.find("##{@prefix}-#{id}"))
          .template = this
      return

  class @View extends View
    include @, publicMethods

    constructor: (@ace, others...) ->
      super others...

  class @Model extends Model
    @prototype.newModel = publicMethods.newModel

    constructor: (@ace, coll, idOrSpec) ->
      super coll, @ace.db, idOrSpec

  class @Controller extends Controller
    include @, publicMethods

    constructor: (@ace, others...) -> super others...

  constructor: (@historyOutlets = new HistoryOutlets, @db = new Db, @name='') ->
    @path = [@name]
    @ace = this
    @modelCache = {}

    @root = @newOutlet('root')
    @rootType = @newOutlet('rootType')
    @rootType.set('body') unless @rootType.get()

    @rootType.outflows.add => @_setRoot()

    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) =>
        outlet = @historyOutlets.sliding.get path
        outlet.auto = true
        outlet.set fn
        outlet

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
      @root.get().appendTo(@$container)
    return

module.exports = Ace

# add OJSON serialization functions
require('./ace_ojson')(Ace)
