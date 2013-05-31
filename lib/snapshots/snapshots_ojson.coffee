OJSON = require '../ojson'
{extend, include} = require '../mixin'

module.exports = (Snapshots) ->
  OJSON.register 'S': Snapshots,
    'S.C': Snapshots.Compound
    'S.S': Snapshots.Snapshot

  Snapshots.Snapshot.prototype['_ojson'] = true
  Snapshots.Compound.prototype['_ojson'] = true
  
  restore = (obj) ->
    if obj['_parent']?
      inst = Object.create obj['_parent']
      inst['_parent'] = obj['_parent']
    else
      inst = new @
    inst[k] = v for k,v of obj when k not in ['_parent', '_ojson']
    inst

  Snapshots.Compound.fromJSON = restore
  Snapshots.Snapshot.fromJSON = restore

  Snapshots.prototype.toJSON = -> OJSON.toOJSON @array
  Snapshots.fromJSON = (obj) -> new Snapshots obj
