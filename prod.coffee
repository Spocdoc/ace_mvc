Socket = require '../lib/socket'
Db = require '../lib/db'
Ace = require '../lib/ace'
sockHandleConnection = require './lib/socket/handle_connection'

module.exports = (server, manifest, bundleSpec, options) ->
  sockServer = new Socket server, options
  db = new Db options

  MediatorClient = require './lib/socket/mediator_client'
  MediatorServer = require './lib/socket/mediator_server'
  if makeMediator = manifest['mediator'] && require manifest['mediator']
    MediatorClient = makeMediator MediatorClient
    MediatorServer = makeMediator MediatorServer

  SockioEmulator = require './lib/socket/emulator'
  sockEmulator = -> new SockioEmulator db, MediatorServer

  sockServer.on 'connection', (sock) ->
    sock.mediator = new MediatorClient db, sock
    sockHandleConnection sock

  new Ace manifest, bundleSpec, options, sockEmulator
