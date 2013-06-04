debugModel = global.debug 'ace:mvc:model'
debugCascade = global.debug 'ace:cascade'
Statelet = require '../cascade/statelet'
Outlet = require '../cascade/outlet'
OutletMethod = require '../cascade/outlet_method'
Auto = require '../cascade/auto'
diff = require '../diff'

module.exports = (Ace) ->

  makeOutletPath = (inst, name) ->
    path = inst._path.concat()
    switch inst.constructor
      when Ace.View then name = "$#{name}"
      when Ace
        name = "#{path[0]}-#{name}"
        path = []
    path.push name
    path

  diff: diff
    
  local: (path) -> @ace.historyOutlets.noInherit(path)

  to: (path) ->
    path = makeOutletPath(this, path) unless ~path.indexOf '/'
    outlet = @ace.historyOutlets.to.get(path)
    outlet.auto = true
    debugCascade "created #{outlet} at #{if typeof path is 'string' then path else path.join('/')}"
    outlet

  from: (path) ->
    path = makeOutletPath(this, path) unless ~path.indexOf '/'
    outlet = @ace.historyOutlets.from.get(path)
    outlet.auto = true
    debugCascade "created #{outlet} at #{if typeof path is 'string' then path else path.join('/')}"
    outlet

  sliding: (path) ->
    path = makeOutletPath(this, path) unless ~path.indexOf '/'
    outlet = @ace.historyOutlets.sliding.get(path)
    outlet.auto = true
    debugCascade "created #{outlet} at #{if typeof path is 'string' then path else path.join('/')}"
    outlet

  newAuto: (init, options) -> new Auto init, options
  newOutlet: (init, options) -> new Outlet init, options

  newController: (type, name, settings) -> debugCascade "creating new controller",type,name; new Ace.Controller(@ace,type, this, name, settings)
  newView: (type, name, settings) -> debugCascade "creating new view",type,name; new Ace.View(@ace, type, this, name, settings)
  newTemplate: (type) -> debugCascade "creating new template",type; new Ace.Template(@ace, type, this)

  newOutletMethod: (func, debug) ->
    om = new OutletMethod func, @outlets, silent: !!func.length, context: this, auto: true
    debugCascade "created outlet method for #{debug}: #{om}"
    om

  # spec and id are optional
  newModel: (type, id, spec) ->
    debugCascade "creating new model",type,id,spec
    [id,spec] = [undefined, id] unless spec or id instanceof global.mongo.ObjectID or typeof id is 'string'

    if exists = @ace.modelCache[type]?[id]
      debugModel "reusing existing model"
      return exists

    model = new Ace.Model(@ace, type, id, spec)
    (@ace.modelCache[type] ||= {})[model.id] = model

  navigate: -> @ace.routing.navigate()

  newStatelet: (name) ->
    hdOutlet = @ace.historyOutlets.sliding.get path = makeOutletPath(this, name)
    statelet = new Statelet undefined, enableSet: @inWindow, silent: true
    statelet.set hdOutlet._value # so it propagates the update
    hdOutlet.set(statelet) # so it synchronizes with the history outlets store

    @ace.historyOutlets.on 'willNavigate', -> statelet.update()
    debugCascade "created #{statelet} at",path.join('/'),"backed by #{hdOutlet}"
    statelet
