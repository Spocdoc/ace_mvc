
module.exports = (pkg) ->
  ret = {}
  ret.Cascade = require('./cascade')()
  ret.Outlet = require('./outlet')(ret.Cascade)
  pkg.cascade = ret

