OJSON = require '../../ojson'

class Callback
  constructor: (@cb) ->

  reject: (reason) ->
    @cb(['rej',reason])
    @cb = undefined
    return

  doc: (doc) ->
    @cb(['doc',OJSON.toOJSON doc])
    @cb = undefined
    return

  update: (version, ops) ->
    @cb(['up',version,OJSON.toOJSON ops])
    @cb = undefined
    return

  badVer: (current) ->
    if current?
      @cb(['ver',current])
    else
      @cb(['ver'])
    @cb = undefined
    return

  noDoc: ->
    @cb(['no'])
    @cb = undefined
    return

  ok: ->
    @cb()
    @cb = undefined
    return

module.exports = Callback
