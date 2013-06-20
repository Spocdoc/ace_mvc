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
debugModel = global.debug 'ace:mvc:model'
debugCascade = global.debug 'ace:cascade'
publicMethods = require './public_methods'

class Ace
  @['newClient'] = (ojson, routesObj, $container) ->
    global['ace'] = (ojson && OJSON.fromOJSON ojson) || new Ace
    ace['cookies'] = new Cookies
    ace.routing.enable routesObj
    navigator = ace.routing.enableNavigator()
    ace.routing.router.route navigator.url
    ace['appendTo'] $container
    return

  constructor: (@db = new Db, @historyOutlets = new HistoryOutlets, @_name='') ->
    @_path = [@_name]
    ace = @ace = this

    class @Template extends Template
      @_bootstrapped = {} # re-used element ids from the server-rendered dom

      _parent: ace

      constructor: ->
        @ace = ace
        super

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
      include @, publicMethods.prototypeMethods

      _parent: ace

      constructor: ->
        @ace = ace
        extend this, publicMethods.instanceMethods(this)
        super

    class @Controller extends Controller
      include @, publicMethods.prototypeMethods

      _parent: ace

      constructor: ->
        @ace = ace
        extend this, publicMethods.instanceMethods(this)
        super

    class @Model extends Model
      cache = {}

      # spec and id are optional
      constructor: (coll, id, spec) ->
        @ace = ace

        debugCascade "creating new model",coll,id,spec
        [id,spec] = [undefined, id] unless spec or id instanceof global.mongo.ObjectID or typeof id is 'string'

        if exists = cache[coll]?[id]
          debugModel "reusing existing model"
          return exists

        super ace.db, coll, id, spec

        (cache[coll] ||= {})[@id] = this

      @find: (coll, spec, cb) ->
        ace.db.coll(coll).findOne spec, (err, doc) =>
          return cb(err) if err?
          cb null, new this coll, doc.id

      delete: ->
        super
        delete cache[model.id]

    class @RouteContext
      include @, publicMethods.prototypeMethods
      constructor: ->
        @ace = ace
        extend this, publicMethods.instanceMethods(this)
        @_path = ['routing']

    @routing = new Routing this, new @RouteContext,
      ((arg) => @historyOutlets.navigate(arg)), publicMethods.prototypeMethods.sliding

    # exports
    @Model['find'] = @Model.find

  reset: -> global.location.reload()

  toString: -> "Ace [#{@_name}]"

  _nodelegate: true

  'appendTo': (@$container) ->
    (new @Controller 'body')['appendTo'] @$container

module.exports = Ace

# add OJSON serialization functions
require('./ace_ojson')(Ace)
