Routing = require './routing'
HistoryOutlets = require '../snapshots/history_outlets'
Variable = require './variable'

class Ace
  constructor: (@historyOutlets = new HistoryOutlets) ->
    @routing = new Routing this,
      (arg) => @historyOutlets.navigate(arg),
      (path, fn) => new Variable @historyOutlets, path, fn

  push: ->
    @historyOutlets.navigate()
    @routing.push()

module.exports = Ace
