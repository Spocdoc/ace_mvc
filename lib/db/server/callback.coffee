OJSON = require '../../ojson'

class Callback
  constructor: (@cb) ->

  reject: (reason) ->
    @cb(['rej',reason])
    delete this
    return

  doc: (doc) ->
    @cb(['doc',OJSON.toOJSON doc])
    delete this
    return

  update: (version, ops) ->
    @cb(['up',version,OJSON.toOJSON ops])
    delete this
    return

  badVer: (current) ->
    if current?
      @cb(['ver',current])
    else
      @cb(['ver'])
    delete this
    return

  noDoc: ->
    @cb(['no'])
    delete this
    return

  ok: ->
    @cb()
    delete this
    return

module.exports = Callback
