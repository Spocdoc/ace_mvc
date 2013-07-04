module.exports = (pkg) ->

  cascade = pkg.cascade || require('../cascade')(pkg)

  pkg.mvc.Global = class Global
    'global': Global.prototype
    'diff': pkg.diff

    @prototype['Outlet'] = @prototype.Outlet = cascade.Outlet
    @prototype['Auto'] = (arg) -> new cascade.Outlet arg, auto: true
