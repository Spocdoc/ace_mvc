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
    ace['cookies'] = new Cookies
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
      prev = boot[@_prefix]
      boot[@_prefix] = true

      unless !prev && (@$root = @ace.$container?.find("##{@_prefix}")).length
        debugBoot "Not bootstrapping template with prefix #{@_prefix}"
        return super

      debugBoot "Bootstrapping template with prefix #{@_prefix}"
      @$['root'] = @$root
      for id in base.ids
        (@["$#{id}"] = @$[id] = @$root.find("##{@_prefix}-#{id}"))
          .template = this
      return

  class @View extends View
    include @, publicMethods

    constructor: (@ace, others...) ->
      super others...

  class @Model extends Model
    @prototype.newModel = publicMethods.newModel

    constructor: (@ace, coll, id, spec) ->
      super @ace.db, coll, id, spec

  class @Controller extends Controller
    include @, publicMethods

    constructor: (@ace, others...) -> super others...

  class @RouteContext
    include @, publicMethods
    constructor: (@ace) ->
      @_path = ['routing']

  constructor: (@db = new Db, @historyOutlets = new HistoryOutlets, @_name='') ->
    @_path = [@_name]
    @ace = this
    @modelCache = {}

    @root = @to('root')
    @rootType = @to('rootType')
    @rootType.set('body') unless @rootType.get()

    @rootType.outflows.add => @_setRoot()

    @routing = new Routing this, new Ace.RouteContext(this),
      (arg) => @historyOutlets.navigate(arg)

  newRouteContext: ->
    new Ace.RouteContext this

  reset: ->
    global.location.reload()

  deleteModel: (model) ->
    if @modelCache[model.id]
      delete @modelCache[model.id]
      model._delete()
    return

  findModel: (coll, spec, cb) ->
    @db.coll(coll).findOne spec, (err, doc) =>
      return cb(err) if err?
      cb null, @newModel coll, doc.id

  toString: -> "Ace [#{@_name}]"

  _setRoot: ->
    type = @rootType.get()
    return if (root = @root.get())?.type == type
    @historyOutlets.noInherit(@_path)
    root?.remove()
    @root.set(@newController(type))
    @appendTo(@$container) if @$container
    return

  _nodelegate: true

  appendTo: (@$container) ->
    unless @root.get()
      @_setRoot()
    else
      @root.get().appendTo(@$container)
    return

module.exports = Ace

# add OJSON serialization functions
require('./ace_ojson')(Ace)
