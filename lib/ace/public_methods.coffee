debugModel = global.debug 'ace:mvc:model'
debugCascade = global.debug 'ace:cascade'
Statelet = require '../cascade/statelet'
Outlet = require '../cascade/outlet'
diff = require '../diff'

module.exports = (Ace) ->

  makeOutletPath = (inst, name) ->
    path = inst.path.concat()
    switch inst.constructor
      when Ace.View then name = "$#{name}"
      when Ace
        name = "#{path[0]}-#{name}"
        path = []
    path.push name
    path

  diff: diff
    
  newOutlet: (name) ->
    outlet = @ace.historyOutlets.to.get path = makeOutletPath(this, name)
    outlet.auto = true
    debugCascade "created #{outlet} at",path.join('/')
    outlet

  newSlidingOutlet: (name) ->
    outlet = @ace.historyOutlets.sliding.get path = makeOutletPath(this, name)
    outlet.auto = true
    debugCascade "created #{outlet} at",path.join('/')
    outlet

  newFromOutlet: (name) ->
    outlet = @ace.historyOutlets.from.get path = makeOutletPath(this, name)
    outlet.auto = true
    debugCascade "created #{outlet} at",path.join('/')
    outlet

  local: (path) -> @ace.historyOutlets.noInherit(path)
  to: (path) -> @ace.historyOutlets.sliding.get(path).get()
  from: (path) -> @ace.historyOutlets.from.get(path).get()

  newController: (type, name, settings) -> debugCascade "creating new controller",type,name; new Ace.Controller(@ace,type, this, name, settings)
  newView: (type, name, settings) -> debugCascade "creating new view",type,name; new Ace.View(@ace, type, this, name, settings)
  newTemplate: (type) -> debugCascade "creating new template",type; new Ace.Template(@ace, type, this)

  newModel: (type, idOrSpec) ->
    debugCascade "creating new model",type,idOrSpec

    if typeof idOrSpec is 'string' or idOrSpec instanceof ObjectID
      if exists = @ace.modelCache[type]?[idOrSpec]
        debugModel "reusing existing model"
        return exists

    model = new Ace.Model(@ace, type, idOrSpec)
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
