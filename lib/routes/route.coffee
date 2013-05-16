parseRoute = require("./utils").parseRoute
_ = require '../utils'

# inspired by express
# for matching: the querystring and hash are always optional (there can be no
# required variables)
class Route
  constructor: (@path, @qsKey, @outletHash, options={}) ->
    if ~(i = (path=@path).indexOf('#'))
      [hash,path] = [path.substr(i), path.substr(0,i)]

    @specs = []

    # regex & formatters
    [@_rp, @_fp] = parseRoute(path, @specs, options)
    [@_rh, @_fh] = parseRoute(hash, @specs, _.defaults({},options,{optional:true})) if hash

  match: (pathname, hash) ->
    params = []

    return false unless m = @_rp.exec(pathname)
    m.concat(mh[1..]) if mh = @_rh?.exec(hash)

    for val, i in m[1..]
      val = decodeURIComponent(val) if typeof val is 'string'

      if spec=@specs[i]
        params[spec.key] = val
      else
        params.push val

    return params

  matchParams: (params) ->
    for spec in @specs when !spec.optional
      return false unless params[spec.key]?
    for k of @outletHash
      return false unless params[k]?
    return true

  # @returns URI path + fragment formed from parameters
  format: (params) ->
    url = @_fp(params)
    url += hash if @_fh and (hash = @_fh(params)).length > 1
    url


module.exports = Route
