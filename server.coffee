#!/usr/bin/env coffee --nodejs --debug

connect = require 'connect'
express = require 'express'
path = require 'path'
Ace = require './lib/server'

debugger

app = express()
server = require('http').createServer(app)

app.use connect.static path.resolve './public'

app.configure 'development', ->
  app.use connect.logger 'dev'

ace = new Ace
  routes: path.resolve('./app/routes')
  server: server
  root: path.resolve('./app')
  cookies:
    domain: '127.0.0.1'
    secure: false
  bundler:
    closure:
      jar: path.resolve './resources/compiler.jar'
      externs: path.resolve './resources/externs.js'
    cookies:
      domain: '127.0.0.1'
      secure: false
    categories:
      standard: ['ie8']
      nonstandard: ['ie6']
  mvc:
    mediator_factory: path.resolve './app/mediator_factory'
    host: '/tmp/mongodb-27017.sock'
    db: 'test'
    redis:
      host: '/tmp/redis.sock'
      port: 6379
      options:
        retry_max_delay: 30*1000

ace.configure 'development', ->
  ace.set 'debug', true

ace.configure 'production', ->
  ace.set 'debug', false

app.use ace

ace.boot (err) ->
  if err?
    console.error err.stack
    throw err

  server.listen port = 1337, ->
    console.log "listening on #{port}..."

