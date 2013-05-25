`// ==ClosureCompiler==
// @compilation_level ADVANCED_OPTIMIZATIONS
// @js_externs module.exports, a.diff_match_patch, a.diff_match_patch, a.diff_main, a.diff_cleanupEfficiency, a.diff_toDelta, a.diff_fromDelta
// @formatting pretty_print
// ==/ClosureCompiler==
`
gd = new (require('./diff_match_patch').diff_match_patch)

module['exports'] =
  'diff': (from, to, options) ->
    return false if to == from
    d = gd.diff_main(from,to)
    gd.diff_cleanupEfficiency(d)
    gd.diff_toDelta(d)

  'patch': (obj, ops, options) ->
    gd.diff_fromDelta(obj, ops)
