global.assert = require 'assert'
global.chai = require 'chai'
global.expect = chai.expect
global.should = chai.should()
global.sinon = require 'sinon'
global.debug = -> ->
chai.use(require('sinon-chai'))

path = require 'path'

# from http://stackoverflow.com/questions/13227489/how-can-one-get-the-file-path-of-the-caller-function-in-node-js
getStack = ->
  origPrepareStackTrace = Error.prepareStackTrace
  Error.prepareStackTrace = (_, stack) ->
    stack
  err = new Error()
  stack = err.stack
  Error.prepareStackTrace = origPrepareStackTrace
  stack

getCaller = ->
  stack = getStack()
  stack.shift() until stack[0].receiver?.id?
  stack[0].receiver.id

global.lib = (file) ->
  lib = if process.env['MOCHA_COV']? then 'lib-cov' else 'lib'
  dirname = getCaller()
  testDir = path.join process.cwd(), 'test'
  libDir = path.join process.cwd(), lib
  base = path.dirname path.join libDir, dirname.slice(testDir.length)
  p = path.resolve base, file
  require path.resolve base, file

