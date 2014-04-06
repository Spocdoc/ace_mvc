fs = require 'fs'
path = require 'path'
OJSON = require 'ojson'
Reject = require './lib/error/reject'
debug = global.debug 'ace:sock'

defaultReject = (clazz, method) ->
  clazz.prototype[method] = (coll, args...) ->
    return handler[method](args...) if (handler = @handlers[coll])?.constructor.prototype.hasOwnProperty(method)
    len = args.length; reject = new Reject 'UNHANDLED'
    if typeof (fn = args[len-2]) is 'function'
      fn reject
    else
      args[len-1] reject
    return

proxySuper = (proto, baseMethod, method) ->
  proto[method] = ->
    (args = Array.apply(null,arguments)).unshift @coll
    baseMethod.apply this, args

module.exports = (mediatorPath, Session = Object) ->
  handlerFns = {}
  for file in fs.readdirSync mediatorPath
    handlerFns[path.basename file, path.extname file] = require "#{mediatorPath}/#{file}"

  (MediatorBase) ->

    class Handler extends MediatorBase
      constructor: (db, sock, @manifest, @coll, @session, @handlers) -> super

      # the handler's read, delete, etc. don't take the coll as the first argument
      for method in ['create','read','update','delete','run','distinct']
        proxySuper @prototype, MediatorBase.prototype[method], method

    handlerClasses = {}
    handlerClasses[coll] = fn(Handler) for coll, fn of handlerFns

    class Mediator extends MediatorBase

      constructor: ->
        super

        @session = new Session this
        @handlers = {}
        @handlers[coll] = new clazz @db, @sock, @manifest, coll, @session, @handlers for coll, clazz of handlerClasses

      # proxy cookies to call all the handler's cookies functions before responding
      cookies: (cookies, cb) ->
        wait = 1
        done = => cb() unless --wait

        for coll, handler of @handlers when handler.cookies
          ++wait
          handler.cookies cookies, done

        done()
        return

      defaultReject this, method for method in ['create','update','delete','run','distinct']

      # read is done separately because of variable number of arguments
      read: (coll, id, version, query, limit, sort, cb, validateDoc) ->
        # allow optional args 
        ARGS = 8
        if (len = arguments.length) < ARGS
          if typeof arguments[len-2] is 'function'
            # then last 2 were passed
            validateDoc = arguments[len-1]
            arguments[len-1] = null
            cb = arguments[len-2]
            arguments[len-2] = null
          else if len < ARGS-1
            cb = arguments[len-1]
            arguments[len-1] = null

        if (handler = @handlers[coll]) and handler.constructor.prototype.hasOwnProperty('read')
          handler.read id, version, query, limit, sort, cb, validateDoc
        else
          cb new Reject 'UNHANDLED'

