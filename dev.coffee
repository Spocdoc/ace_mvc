Socket = require './lib/socket'
Db = require './lib/db'
_ = require 'lodash-fork'
Emitter = require 'events-fork/emitter'
fs = require 'fs'
path = require 'path'
require 'debug-fork'
SigHandler = require './sig_handler'
OjsonSocket = require './lib/socket/ojson_socket'
debug = global.debug 'ace'
debugSock = global.debug 'ace:sock'
debugError = global.debug 'ace:error'

module.exports = (server, manifest, options) ->
  returnFn = (req, res, next) ->
    return next null if initializing or resetter.running
    ace.handle req, res, next

  _.extend returnFn, Emitter

  {root} = manifest.private
  initializing = true

  sockServer = new Socket server, options
  db = new Db options
  sockEmulator = undefined
  dirWatch = resetter = ace = MediatorClient = MediatorServer = undefined

  sigHandler = new SigHandler server, sockServer, db, returnFn

  sockServer.on 'connection', (sock) ->
    return if initializing or resetter.running
    sock = new OjsonSocket sock # to serialize/deserialize args
    debugSock "new socket.io with id #{sock.id}"
    sock.mediator = new MediatorClient db, sock, manifest
    require('./lib/socket/handle_connection')(sock)

  reset = (done) ->
    return if sigHandler.terminating
    initializing = false

    manifest.update (err) ->
      try
        return console.error err if err?

        # watch all the bundle's sources
        for type in ['js','css']
          for expr, {sources,generated} of manifest.bundle.debug[type]
            sources[i] = path.resolve(root,source) for source, i in sources
            dirWatch sources

        # forcefully disconnect *all* sockets (including socket.IO)
        sigHandler.disconnectSockets()

        db.off()

        debug "building ace"
        try
          MediatorClient = require './lib/socket/mediator_client'
          MediatorServer = require './lib/socket/mediator_server'

          if mediatorGlobals = options.mediatorGlobals
            for k, v of mediatorGlobals
              MediatorClient.prototype[k] = v
              MediatorServer.prototype[k] = v

          if makeMediator = manifest.mediator && require path.resolve(root,manifest.mediator)
            MediatorClient = makeMediator MediatorClient
            MediatorServer = makeMediator MediatorServer

          SockioEmulator = require './lib/socket/emulator'
          sockEmulator = -> new SockioEmulator db, MediatorServer, manifest

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

  returnFn
