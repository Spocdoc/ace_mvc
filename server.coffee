#!/usr/bin/env coffee --nodejs --debug

connect = require 'connect'
express = require 'express'
path = require 'path'
Ace = require './lib/ace/server'
Bundler = require './lib/bundler/server'

debugger

app = express()
server = require('http').createServer(app)
app.use connect.logger 'dev'

bundler = new Bundler
bundler.configure 'development', ->
  bundler.set 'debug', true
app.use bundler

ace = new Ace
  routes: path.resolve('./routes')
  server: server
  mvc:
    files: path.resolve('./app')
    templates: ['htm','html','jade']

ace.configure 'development', ->
  ace.set 'db',
    host: '/tmp/mongodb-27017.sock'
    db: 'test'
    redis:
      host: '/tmp/redis.sock'
      port: 6379
      options:
        retry_max_delay: 30*1000

app.use ace

app.listen port = 1337, ->
  console.log "listening on #{port}..."
