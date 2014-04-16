Socket = require './lib/socket'
Db = require './lib/db'
Ace = require './lib/ace'
path = require 'path'
sockHandleConnection = require './lib/socket/handle_connection'
SigHandler = require './sig_handler'
OjsonSocket = require './lib/socket/ojson_socket'
_ = require 'lodash-fork'
Emitter = require 'events-fork/emitter'

module.exports = (server, manifest, options) ->
  {root} = manifest.private

  sockServer = new Socket server, options
  db = new Db options

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

  sockServer.on 'connection', (sock) ->
    sock = new OjsonSocket sock # to serialize/deserialize args
    sock.mediator = new MediatorClient db, sock, manifest
    sockHandleConnection sock

  options['release'] = true
  ace = new Ace manifest, options, sockEmulator
  sigHandler = new SigHandler server, sockServer, db, ace
  _.extend ace, Emitter
  ace

