#!/usr/bin/env coffee#--nodejs --debug-brk

closurify = require 'closurify'
path = require 'path'
fs = require 'fs'
glob = require 'glob'
async = require 'async'
os = require 'os'
beautify = require('js-beautify').js_beautify
coffee = require 'coffee-script'

getModTime = (filePath, cb) ->
  fs.stat filePath, (err, stat) ->
    return cb(err) if err?
    cb null, stat.mtime.getTime()

readFile = (filePath, cb) -> fs.readFile filePath, 'utf-8', cb

options =
  closure:
    jar: path.resolve '../resources/compiler.jar'
    externs: [
      path.resolve '../resources/externs.js'
      path.resolve '../resources/externs-test.js'
      path.resolve '../resources/externs-server.js'
    ]
  release: true

getLibPath = (outPath) ->
  dir = path.dirname outPath
  lib = path.resolve "../lib/#{dir}"
  path.relative dir, lib

_writeClosure = (inPath, outPath, logPath, cb) ->
  console.log "Compiling #{inPath}"
  async.waterfall [
    (next) -> readFile inPath, next
    (code, next) ->
      lib = getLibPath outPath
      code = coffee.compile(code, bare: true)
      # TODO should use uglify AST for this
      code = code.replace(/\blib\b\(['"]([^'"]+)['"]\)/g, """require("#{lib}/$1")""")
      fs.writeFile outPath, code, next
    (next) ->
      closurify [outPath], options, (err, debug, release, stderr) ->
        async.series [
          (done) ->
            if stderr
              fs.writeFile logPath, stderr, done
            else
              fs.unlink logPath, -> done()
          (done) ->
            if release
              fs.writeFile outPath, beautify(release, indent_size: 2), done
            else
              done new Error("Got an empty closure compile for #{inPath}")
          ], next
  ], cb

writeClosure = (inPath, cb) ->
  outPath = inPath.replace(/.coffee$/,".js")
  logPath = inPath.replace(/.coffee$/,".log")
  return cb new Error "got invalid file?: #{inPath}" if inPath is outPath
  # _writeClosure inPath, outPath, logPath, cb

  async.waterfall [
    (next) -> fs.exists outPath, (exists) -> next null, exists

    (exists, next) ->
      if exists
        async.mapSeries [outPath,inPath], getModTime, (err, result) ->
          if err?
            next(err)
          else
            next(err, result[0] <= result[1])
      else
        next(null,true)

    (shouldCompile, next) ->
      if shouldCompile
        _writeClosure inPath, outPath, logPath, cb
      else
        next null
    ], cb

if module is require.main

  async.waterfall [
    (next) -> glob './*/**/!(_*).coffee', next
    # (next) -> glob './clone/index.coffee', next
    (files, next) ->
      async.eachLimit files, os.cpus().length, writeClosure, next
    ], (err) ->
      if err?
        console.error err
      else
        console.log "now cd ../ and run mocha"

