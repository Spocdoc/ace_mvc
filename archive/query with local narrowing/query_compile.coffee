deepEqual = require 'diff-fork/deep_equal'
{quote} = require 'lodash-fork'
debug = global.debug 'ace:model:query'
Outlet = require 'outlet'

joinerOp =
  '$and': '&&'
  '$or': '||'
  '$nor': '||'

nameToOp =
  '$gt': '>'
  '$lt': '<'
  '$gte': '>='
  '$lte': '<='
  '$ne': '!=='

parsePart = (field, spec, func) ->
  if spec instanceof RegExp
    func = func + "&& #{spec}.test(#{field})"
  else if typeof spec is 'object'
    for k,v of spec
      v = v.value if v instanceof Outlet
      continue unless v?
      switch k
        when '$mod' then func = func + "&& #{field}%#{v[0]}===#{v[1]}"
        when '$regex' then func = func + "&& match.call(#{field},#{quote(v)})!=null"
        when '$all' then func = func + "&& ~indexOf.call(#{field},#{quote(elem)})" for elem in v

        when '$gt', '$gte', '$lt', '$lte', '$ne'
          if typeof v is 'number' or ''+(0+v) is v
            func = func + "&& #{field}#{nameToOp[k]}#{v}"
          else
            func = func + "&& +#{field}#{nameToOp[k]}#{+v}"

        when '$in'
          arr2 = ''
          arr2 = arr2 + "|| ~indexOf.call(#{field},#{quote(elem)})" for elem in v
          func = func + "&& (#{arr2.substr(3)})"
        when '$nin'
          arr2 = ''
          arr2 = arr2 + "&& !~indexOf.call(#{field},#{quote(elem)})" for elem in v
          func = func + "&& (#{field}==null || (#{arr2.substr 3}))"
        when '$elemMatch'
          arr2 = parseClause "f[i]", v, ''
          func = func + """&& (function(){var f = #{field}; for(var i=0,j=f.length;i<j;++i)if(#{arr2.substr 3})return true;return false;})()"""
        when '$size' then func = func + "&& #{field}.length === #{v}"
        when '$not'
          arr2 = parsePart field, v, ''
          func = func + "&& !(#{arr2.substr 3})"
        else
          return func + "&& deepEqual(#{field},#{JSON.stringify spec})"
  else
    func = func + "&& #{field}===#{quote(spec)}"

  func


parseClause = (doc, spec, func) ->
  for k,v of spec
    if op = joinerOp[k]
      arr2 = ''
      arr2 = "#{arr2}#{op} (#{parseClause(doc, clause, '').substr(3)})" for clause in v
      func = "#{func}&& #{if k.charAt(1) is 'n' then '!' else ''}(#{arr2.substr(3)})"
    else unless k is '$text' # full text search is too complex to do locally
      field = ''
      field = field + "[#{quote part}]" for part in k.split '.'

      func = parsePart "#{doc}#{field}", v, func

  func

module.exports = (spec) ->
  func = parseClause 'doc', spec, ''
  func = "return #{func.substr(2)||true};"
  debug "compiled query to #{func}"
  func = new Function 'deepEqual', 'match', 'indexOf', 'doc', func
  (model) ->
    return false unless doc = model.clientDoc
    func(deepEqual, String.prototype.match, Array.prototype.indexOf, doc)

