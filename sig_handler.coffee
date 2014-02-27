debug = global.debug 'ace'
debugError = global.debug 'ace:error'
_ = require 'lodash-fork'

# max time to wait for server.close()
if process.env.NODE_ENV is 'production'
  MAX_CLOSE_MILLIS = 10000
else
  MAX_CLOSE_MILLIS = 500

module.exports = class SigHandler
  constructor: (server, sockServer, db) ->
    @socketConnections = socketConnections = {}

    @terminating = didTerminate = terminating = false

    onClose = =>
      return if didTerminate
      didTerminate = true

      # just in case some connections have not ended despite the close event (? still see ESTABLISHED connections after the close event...)
      @disconnectSockets()

      debug "Sockets disconnected. Closing database..."

      # once there are no outstanding connections, close the mongodb connections, which will also quit the redis connections
      db.close ->
        debug "Database closed."

        # disconnect from IPC channel
        process.disconnect?()

        # now the program should exit on its own
        return
      return

    terminate = =>
      return if terminating
      @terminating = terminating = true

      debug "Got SIGTERM"

      debugger

      # stop accepting new connections
      server.close()

      # forcefully kick off any socket.io connections
      sockServer.exit()

      # only wait up to MAX_CLOSE_MILLIS milliseconds for the connections to close
      timeout = setTimeout (->
        unless didTerminate
          debugError "Warning: timed out after #{MAX_CLOSE_MILLIS} milliseconds waiting for server close event."
          onClose()
        ), MAX_CLOSE_MILLIS
      timeout.unref() # prevent this timeout from delaying the program close
      return

    process.on 'SIGINT', terminate
    process.on 'SIGTERM', terminate

    server.on 'close', onClose

    server.on 'connection', (sock) ->
      socketConnections[id = sock.aceId = _.makeId()] = sock
      sock.on 'close', -> delete socketConnections[id]

  # kicks off *all* client connections to the server
  disconnectSockets: ->
    for id, sock of @socketConnections
      sock.end()
      sock.destroy()
    return

