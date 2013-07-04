module.exports = (pkg) ->
  pkg.cascade || require('../cascade')(pkg)

  mvc = pkg.mvc = {}

  require('./global')(pkg)

  require('./template')(pkg)
  require('./model')(pkg)

  require('./controller_base')(pkg)
  require('./view')(pkg)
  require('./controller')(pkg)

  mvc
