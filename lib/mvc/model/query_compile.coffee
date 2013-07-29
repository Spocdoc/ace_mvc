deepEqual = require '../../utils/deep_equal'
quote = require '../../utils/quote'
debug = global.debug 'ace:model:query'

joinerOp =
  '$and': '&&'
  '$or': '||'
  '$nor': '||'

parsePart = (field, spec, func) ->
  if spec instanceof RegExp
    func.push "match.call(#{field},#{spec}) != null"
  else if typeof spec is 'object'
    arr1 = []

    for k,v of spec
      switch k
        when '$mod' then arr1.push "#{field}%#{v[0]}===#{v[1]}"
        when '$regex' then arr1.push "match.call(#{field},#{quote(v)})!=null"
        when '$all' then arr1.push "~indexOf.call(#{field},#{quote(elem)})" for elem in v
        when '$gt' then arr1.push "#{field}>#{v}"
        when '$gte' then arr1.push "#{field}>=#{v}"
        when '$lt' then arr1.push "#{field}<#{v}"
        when '$lte' then arr1.push "#{field}<=#{v}"
        when '$ne' then arr1.push "#{field}!==#{v}"
        when '$in'
          arr2 = []
          arr2.push "~indexOf.call(#{field},#{quote(elem)})" for elem in v
          arr1.push arr2.join '||'
        when '$nin'
          arr2 = []
          arr2.push "!~indexOf.call(#{field},#{quote(elem)})" for elem in v
          arr1.push "(#{field}==null||(#{arr2.join '&&'}))"
        when '$elemMatch'
          arr2 = []
          parseClause "#{field}[i]", v, arr2
          arr1.push """(function(){for(var i=0,j=#{field}.length;i<j;++i)if(#{arr2.join '&&'})return true;return false;})()"""
        when '$size' then arr1.push "#{field}.length === #{v}"
        when '$not'
          arr2 = []
          parsePart field, v, arr2
          arr1.push "!(#{arr2.join "&&"})"
        when '$text' then # no-op. skip text search criteria -- they can't be done locally
        else
          arr1.push "deepEqual(#{field}[#{quote(k)}],#{quote(v)})"

    func.push arr1.join '&&'
  else
    func.push "#{field}===#{quote(spec)}"

  return


parseClause = (doc, spec, func) ->
  arr1 = []

  for k,v of spec
    if op = joinerOp[k]
      arr2 = []
      parseClause doc, clause, arr2 for clause in v
      arr1.push "#{if k.charAt(1) is 'n' then '!' else ''}(#{arr2.join op})"
    else
      parsePart "#{doc}[#{quote(k)}]", v, arr1

  func.push arr1.join '&&'

  return

module.exports = (spec) ->
  func = []
  parseClause 'doc', spec, func
  func = """return #{func.join ''};"""
  debug "compiled query to #{func}"
  func = new Function 'deepEqual', 'match', 'indexOf', 'doc', func
  (model) ->
    return false unless doc = model.clientDoc
    func(deepEqual, String.prototype.match, Array.prototype.indexOf, doc)

