Socket = require './lib/socket'
Db = require './lib/db'
_ = require 'lodash-fork'
fs = require 'fs'
path = require 'path'
require 'debug-fork'
debug = global.debug 'ace'
debugError = global.debug 'ace:error'

module.exports = (server, manifest, options) ->
  {root} = manifest.private
  initializing = true

  sockServer = new Socket server, options
  db = new Db options
  sockEmulator = undefined
  socketConnections = {}
  dirWatch = resetter = ace = MediatorClient = MediatorServer = undefined

  server.on 'connection', (sock) ->
    socketConnections[id = sock.aceId = _.makeId()] = sock
    sock.on 'close', -> delete socketConnections[id]

  sockServer.on 'connection', (sock) ->
    return if initializing or resetter.running
    sock.mediator = new MediatorClient db, sock
    require('./lib/socket/handle_connection')(sock)

  reset = (done) ->
    initializing = false

    manifest.update (err) ->
      try
        return console.error err if err?

        # watch all the bundle's sources
        for type in ['js','css']
          for expr, {sources,generated} of manifest.bundle.debug[type]
            sources[i] = path.resolve(root,source) for source, i in sources
            dirWatch sources

        # disconnect sockets
        for id, sock of socketConnections
          sock.end()
          sock.destroy()

        db.off()

        debug "building ace"
        try
          MediatorClient = require './lib/socket/mediator_client'
          MediatorServer = require './lib/socket/mediator_server'
          if makeMediator = manifest.mediator && require path.resolve(root,manifest.mediator)
            MediatorClient = makeMediator MediatorClient
            MediatorServer = makeMediator MediatorServer

          SockioEmulator = require './lib/socket/emulator'
          sockEmulator = -> new SockioEmulator db, MediatorServer

          Ace = require './lib/ace'
          ace = new Ace manifest, options, sockEmulator
        catch _error
          debugError _error?.stack

        debug "Done resetting"
        return
      finally
        done()

  dirWatch = _.watchRequires reset
  resetter = dirWatch.callback

  resetter()

  (req, res, next) ->
    return next null if initializing or resetter.running
    ace.handle req, res, next
