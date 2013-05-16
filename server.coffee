#!/usr/bin/env coffee

connect = require 'connect'
express = require 'express'
path = require 'path'
Ace = require './lib/ace/server'

app = express()
server = require('http').createServer(app)
app.use connect.logger 'dev'

ace = new Ace
  routes: path.resolve('./routes')
  server: server

ace.configure 'development', ->
  ace.set 'db',
    server: '/tmp/mongodb-27017.sock'
    db: 'test'
    redis:
      host: '/tmp/redis.sock'
      port: 6379
      options:
        retry_max_delay: 30*1000

app.use ace

app.listen port = port, ->
  console.log "listening on #{port}..."
