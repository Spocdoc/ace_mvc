Socket = require './lib/socket'
Db = require './lib/db'
Ace = require './lib/ace'
path = require 'path'
sockHandleConnection = require './lib/socket/handle_connection'
SigHandler = require './sig_handler'

module.exports = (server, manifest, options) ->
  {root} = manifest.private

  sockServer = new Socket server, options
  db = new Db options

  MediatorClient = require './lib/socket/mediator_client'
  MediatorServer = require './lib/socket/mediator_server'
  if makeMediator = manifest.mediator && require path.resolve(root,manifest.mediator)
    MediatorClient = makeMediator MediatorClient
    MediatorServer = makeMediator MediatorServer

  SockioEmulator = require './lib/socket/emulator'
  sockEmulator = -> new SockioEmulator db, MediatorServer

  sockServer.on 'connection', (sock) ->
    sock.mediator = new MediatorClient db, sock
    sockHandleConnection sock

  sigHandler = new SigHandler server, sockServer, db

  options['release'] = true

  new Ace manifest, options, sockEmulator

