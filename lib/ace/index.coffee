Routing = require './routing'
HistoryOutlets = require '../snapshots/history_outlets'

class Ace
  constructor: (@historyOutlets = new HistoryOutlets) ->
    @routing = new AceRouting this, (arg) => @historyOutlets.navigate(arg)

  push: ->
    @historyOutlets.navigate()
    @routing.push()

module.exports = Ace
