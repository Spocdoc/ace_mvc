module.exports.routes = (match) ->
  match '/:text'
  # match '/'

module.exports.vars = (outlets, Variable, ace) ->
  outlets.text.set new Variable 'content/$root'
