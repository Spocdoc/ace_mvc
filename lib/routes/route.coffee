utils = require("./utils")
_ = require('underscore')._

# inspired by express
# for matching: the querystring and hash are always optional (there can be no
# required variables)
class Route
  constructor: (@path, @qsKey, @outlets, options={}) ->
    if ~(i = (path=@path).indexOf('#'))
      [hash,path] = [path.substr(i), path.substr(0,i)]

    @keys = []

    # regex & formatters
    [@_rp, @_fp] = utils.parseRoute(path, keys, options)
    [@_rh, @_fh] = utils.parseRoute(hash, keys, _.defaults({},options,{optional:true})) if hash

  match: (pathname, hash) ->
    params = []

    return false unless m = @_rp.exec(pathname)
    m.concat(mh[1..]) if mh = @_rh?.exec(hash)

    for val, i in m[1..]
      val = decodeURIComponent(val) if typeof val is 'string'

      if key=@keys[i]
        params[key.name] = val
      else
        params.push val

    return params

  matchParams: (params) ->
    for spec in @keys when !spec.optional
      return false unless params[spec.name]?
    for k of @outlets
      return false unless params[k]?
    return true

  # @returns URI path + fragment formed from parameters
  format: (params) ->
    url = @_fp(params)
    url += hash if @_fh and (hash = @_fh(params)).length > 1
    url


module.exports = Route
