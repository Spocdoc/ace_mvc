#!/usr/bin/env coffee#--nodejs --debug-brk

connect = require 'connect'
express = require 'express'
path = require 'path'
Ace = require './lib/ace/server'

debugger

app = express()
server = require('http').createServer(app)

app.configure 'development', ->
  app.use connect.logger 'dev'

ace = new Ace
  routes: path.resolve('./routes')
  server: server
  mvc:
    files: path.resolve('./app')
    templates: ['htm','html','jade']
  bundler:
    closure:
      jar: path.resolve './resources/compiler.jar'
      externs: path.resolve './resources/externs.js'

ace.configure 'development', ->
  ace.set 'debug', true
  ace.set 'db',
    host: '/tmp/mongodb-27017.sock'
    db: 'test'
    redis:
      host: '/tmp/redis.sock'
      port: 6379
      options:
        retry_max_delay: 30*1000

ace.configure 'production', ->
  ace.set 'debug', false
  ace.set 'db',
    host: '/tmp/mongodb-27017.sock'
    db: 'test'
    redis:
      host: '/tmp/redis.sock'
      port: 6379
      options:
        retry_max_delay: 30*1000

app.use ace

server.listen port = 1337, ->
  console.log "listening on #{port}..."
