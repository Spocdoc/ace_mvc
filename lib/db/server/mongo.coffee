queue = require '../../queue'
mongodb = require 'mongodb'

class Mongo
  constructor: (host, db) ->
    @server = new mongodb.Server(host)
    @db = new mongodb.Db db, @server,
      w: 1
      native_parser: true
      logger: console
    @colls = {}
    @_connect()
    @q = queue()

  _connect: ->
    @connected = false # whenever this is false, you're connecting
    @db.open (err) =>
      if err?
        setTimeout (=> @_connect()), 500
      else
        @_onConnect()
      return

  _onConnect: ->
    unless args = @q()
      @connected = true
      return

    @_run args[0...-1]..., (err, res) =>
      if @db.state isnt 'connected'
        @q.unshift(args)
        @_connect()
      else
        args[args.length-1](err, res)
        @_onConnect()
      return

    return

  _run: (cmd, coll, args..., cb) ->
    coll = @colls[coll] ||= @db.collection(coll)
    coll[cmd](args...,cb)
    return

  run: (cmd, coll, args..., cb) ->
    if @connected
      @_run cmd, coll, args..., (err, res) =>
        if @db.state isnt 'connected'
          @q([cmd, coll, args..., cb])
          @_connect() if @connected
        else
          cb(err, res)
        return
    else
      @q([cmd, coll, args..., cb])
    return

module.exports = Mongo

