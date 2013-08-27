Socket = require '../lib/socket'
Db = require '../lib/db'
_ = require 'lodash-fork'

fixedRequires = {}
fixedRequires[k] = 1 for k of require.cache

module.exports = (server, manifest, bundleSpec, options, bundle) ->
  sockServer = new Socket server, options
  db = new Db options
  sockEmulator = undefined

  server.on 'connection', do ->
    socketConnections = {}
    (sock) ->
      socketConnections[id = sock.aceId = _.makeId()] = sock
      sock.on 'close', -> delete socketConnections[id]

  resetting = true
  ace = MediatorClient = MediatorServer = undefined

  sockServer.on 'connection', (sock) ->
    return if resetting
    sock.mediator = new MediatorClient db, sock
    require('../lib/socket/handle_connection')(sock)

  watching = {}

  watch = (filePath) ->
    unless watching[filePath]
      watching[filePath] = true
      fs.watch filePath, reset
    return

  doReset = ->
    for id, sock of socketConnections
      sock.end()
      sock.destroy()

    db.off()

    for req of require.cache when !fixedRequires[req]
      delete require.cache[req]

    watch filePath for type, filePath of manifest['files']['style']
    watch filePath for type, filePath of manifest['files']['template']

    ace = undefined

    MediatorClient = require '../lib/socket/mediator_client'
    MediatorServer = require '../lib/socket/mediator_server'
    if makeMediator = manifest['mediator'] && require manifest['mediator']
      MediatorClient = makeMediator MediatorClient
      MediatorServer = makeMediator MediatorServer

    SockioEmulator = require '../socket/emulator'
    sockEmulator = new SockioEmulator db, MediatorServer

    resetting = false

  doBundle = (done) ->
    bundle manifest, (err, spec) ->
      if err?
        console.error err
        return done()
      watch filePath for filePath in spec['files']
      bundleSpec = spec
      done -> doReset
    return

  reset = _.debounce 0, _.debounceAsync (done) ->
    resetting = true
    next = ->
      if bundle
        doBundle done
      else
        done -> doReset
    if typeof manifest.reload is 'function'
      manifest.reload next
    else
      next()
    return

  reset()

  i = (requires = Object.keys fixedRequires).length
  (req, res, next) ->
    if resetting
      next null
      return

    unless ace
      Ace = require '../lib/ace'
      ace = Ace.newServer manifest, bundleSpec, options, sockEmulator

    ace.handle req, res, next, ->
      iE = (requires = Object.keys require.cache)
      watch requires[i++] while i < iE
      return
