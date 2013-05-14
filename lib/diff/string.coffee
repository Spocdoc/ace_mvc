gd = new (require('./diff_match_patch-min')['diff_match_patch'])

module['exports'] =
  'diff': (from, to, options) ->
    return false if to == from
    d = gd['diff_main'](from,to)
    gd['diff_cleanupEfficiency'](d)
    gd['diff_toDelta'](d)

  'patch': (obj, ops, options) ->
    gd['diff_fromDelta'](obj, ops)