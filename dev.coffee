Socket = require './lib/socket'
Db = require './lib/db'
_ = require 'lodash-fork'
fs = require 'fs'
require 'debug-fork'
debug = global.debug 'ace'
debugError = global.debug 'ace:error'
nodeWatch = require 'node-watch'

fixedRequires = undefined

module.exports = (server, manifest, bundleSpec, options, bundle) ->
  unless fixedRequires
    fixedRequires = {}
    fixedRequires[k] = 1 for k of require.cache

  sockServer = new Socket server, options
  db = new Db options
  sockEmulator = undefined
  socketConnections = {}

  server.on 'connection', (sock) ->
    socketConnections[id = sock.aceId = _.makeId()] = sock
    sock.on 'close', -> delete socketConnections[id]

  resetting = true
  ace = MediatorClient = MediatorServer = undefined

  sockServer.on 'connection', (sock) ->
    return if resetting
    sock.mediator = new MediatorClient db, sock
    require('./lib/socket/handle_connection')(sock)

  watching = {}

  watch = (filePath) ->
    unless watching[filePath]
      watching[filePath] = true
      nodeWatch filePath, ->
        debug "#{filePath} changed"
        reset()
      debug "watching #{filePath}"
    return

  doReset = ->
    debug "clearing sockets"
    for id, sock of socketConnections
      sock.end()
      sock.destroy()

    db.off()

    for req of require.cache when !fixedRequires[req]
      delete require.cache[req]

    if filePath = manifest['index']
      watch filePath

    watch filePath for type, filePath of manifest['files']['style']
    watch filePath for type, filePath of manifest['files']['template']

    MediatorClient = require './lib/socket/mediator_client'
    MediatorServer = require './lib/socket/mediator_server'
    if makeMediator = manifest['mediator'] && require manifest['mediator']
      MediatorClient = makeMediator MediatorClient
      MediatorServer = makeMediator MediatorServer

    SockioEmulator = require './lib/socket/emulator'
    sockEmulator = -> new SockioEmulator db, MediatorServer

    debug "rebuilding ace"
    try
      Ace = require './lib/ace'
      ace = new Ace manifest, bundleSpec, options, sockEmulator
    catch _error
      debugError _error?.stack

    debug "Done resetting"
    resetting = false

  doBundle = (done) ->
    debug "bundling"
    bundle manifest, (err, spec) ->
      if err?
        console.error err
        return done()
      for expr, arr of spec.js
        watch filePath for filePath in arr['files']
      bundleSpec = spec
      debug "done bundling"
      done -> doReset()
    return

  reset = _.debounce 100, _.debounceAsync (done) ->
    resetting = true
    debug "Resetting..."
    next = (err) ->
      if err?
        console.error err.stack
        resetting = false
        return
      if bundle
        doBundle done
      else
        done -> doReset()
    if typeof manifest.reload is 'function'
      debug "reloading manifest"
      manifest.reload next
    else
      next()
    return

  reset()

  i = (requires = Object.keys fixedRequires).length
  addRequires = ->
    iE = (requires = Object.keys require.cache).length
    watch requires[i++] while i < iE
    return
  (req, res, next) ->
    if resetting
      next null
      return

    try
      ace.handle req, res, next, addRequires
    catch _error
      addRequires()
      throw _error
