{queue} = require 'lodash-fork'
mongodb = require 'mongo-fork'

regexAllSpace = /\s/g
regexCurlySingle = /[\u2018\u2019]/g
regexCurlyDouble = /[\u201c\u201d]/g

module.exports = class Mongo
  # port is optional
  constructor: (db, host, port) ->
    @server = if port then new mongodb.Server(host, port) else new mongodb.Server(host)
    @db = new mongodb.Db db, @server,
      w: 1
      native_parser: true
      logger: console
    @colls = {}
    @_connect()
    @q = queue()

  # closes the database connection and disconnects redis pub/sub
  close: (cb) ->
    return if @closed
    @connected = false
    @closed = true

    @db.close =>
      # TODO this is a lousy workaround for an apparent mongo bug -- connections in the internal pool are opened on a timer and close won't prevent new opens in some cases
      setTimeout ( =>
        if cb
          @db.close cb
        else
          @db.close()
      ), 5000
    return

  _connect: ->
    return if @closed

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

  _run: (cmd, collName, args..., cb) ->
    coll = @colls[collName] ||= @db.collection(collName)
    if cmd is 'find'
      coll[cmd](args...).toArray cb
    else if coll[cmd]
      coll[cmd](args...,cb)
    else if cmd is 'text'
      # ridiculous. the order of key traversal is important to mongo -- cmd has
      # to be first key so an object has to be created every time
      obj = {}
      obj[cmd] = collName
      obj[k] = v for k, v of args[0]

      # search field won't filter properly with nonbreaking space, curly quotes
      if search = obj['search']
        obj['search'] = search.replace(regexAllSpace,' ').replace(regexCurlySingle,'\'').replace(regexCurlyDouble,'"')

      @db.command obj, (err, result) ->
        return cb err if err?
        results[i] = result['obj'] for result,i in results if results = result?['results']
        cb err, results
    else
      cb new Error("unhandled command [#{cmd}]")
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

