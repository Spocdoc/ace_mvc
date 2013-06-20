debugModel = global.debug 'ace:mvc:model'
debugCascade = global.debug 'ace:cascade'
Statelet = require '../cascade/statelet'
Outlet = require '../cascade/outlet'
OutletMethod = require '../cascade/outlet_method'
Auto = require '../cascade/auto'
diff = require '../diff'
View = require '../mvc/view'

makeOutletPath = (inst, name) ->
  path = inst._path.concat()
  name = "$#{name}" if inst instanceof View
  path.push name
  path

module.exports =
  prototypeMethods:

    'diff': diff
      
    'local': (path) -> @ace.historyOutlets.noInherit(path)

    'to': (path) ->
      path = makeOutletPath(this, path) unless ~path.indexOf '/'
      outlet = @ace.historyOutlets.to.get(path)
      outlet.auto = true
      debugCascade "created #{outlet} at #{if typeof path is 'string' then path else path.join('/')}"
      outlet

    'from': (path) ->
      path = makeOutletPath(this, path) unless ~path.indexOf '/'
      outlet = @ace.historyOutlets.from.get(path)
      outlet.auto = true
      debugCascade "created #{outlet} at #{if typeof path is 'string' then path else path.join('/')}"
      outlet

    'sliding': (path) ->
      path = makeOutletPath(this, path) unless ~path.indexOf '/'
      outlet = @ace.historyOutlets.sliding.get(path)
      outlet.auto = true
      debugCascade "created #{outlet} at #{if typeof path is 'string' then path else path.join('/')}"
      outlet

    'navigate': -> @ace.routing.navigate()

    'Auto': Auto
    'Outlet': Outlet

  instanceMethods: (self) ->
    
    'OutletMethod': class OutletMethodLocal extends OutletMethod
      constructor: (func, debug) ->
        super func, self.outlets, silent: !!func.length, context: self, auto: true
        debugCascade "created outlet method for #{debug}: #{this}"

    'Statelet': class StateletLocal extends Statelet
      constructor: (name) ->
        hdOutlet = self.ace.historyOutlets.sliding.get path = makeOutletPath(self, name)
        super undefined, enableSet: self.inWindow, silent: true
        @set hdOutlet._value # so it propagates the update
        hdOutlet.set(this) # so it synchronizes with the history outlets store

        self.ace.historyOutlets.on 'willNavigate', => @update()
        debugCascade "created #{@} at",path.join('/'),"backed by #{hdOutlet}"

    'Controller': class ControllerLocal extends self.ace.Controller
      _parent: self

      constructor: (type, name, settings) ->
        debugCascade "creating new controller",type,name
        super type, name, settings

    'View': class ViewLocal extends self.ace.View
      _parent: self

      constructor: (type, name, settings) ->
        debugCascade "creating new view",type,name
        super type, name, settings

    'Template': class TemplateLocal extends self.ace.Template
      _parent: self

      constructor: (type) ->
        debugCascade "creating new template",type
        super type

    'Model': self.ace.Model
