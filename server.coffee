#!/usr/bin/env coffee --nodejs --debug

connect = require 'connect'
express = require 'express'
path = require 'path'
Ace = require './lib/ace/server'

debugger

app = express()
server = require('http').createServer(app)

app.use connect.static path.resolve './public'

app.configure 'development', ->
  app.use connect.logger 'dev'

ace = new Ace
  routes: path.resolve('./routes')
  server: server
  root: path.resolve('./app')
  cookies:
    domain: '.supamac.local'
    secure: false
  bundler:
    closure:
      jar: path.resolve './resources/compiler.jar'
      externs: path.resolve './resources/externs.js'
    cookies:
      domain: '.supamac.local'
      secure: false

ace.configure 'development', ->
  ace.set 'debug', true
  ace.set 'db',
    mediator: path.resolve './app/mediator'
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
    mediator: path.resolve './app/mediator'
    host: '/tmp/mongodb-27017.sock'
    db: 'test'
    redis:
      host: '/tmp/redis.sock'
      port: 6379
      options:
        retry_max_delay: 30*1000

app.use ace

ace.boot (err) ->
  if err?
    console.error err.stack
    throw err

  server.listen port = 1337, ->
    console.log "listening on #{port}..."

