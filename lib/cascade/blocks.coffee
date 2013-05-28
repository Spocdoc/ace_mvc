debug = global.debug 'ace:cascade:block'

module.exports = (Cascade) ->

  blockRunner = (func) ->
    if Cascade.roots
      ret = func()
    else
      Cascade.roots = []
      Cascade.roots.cids = {}

      debug "Building up Cascade.Block"

      ret = func()

      debug "Running Cascade.Block..."

      roots = Cascade.roots
      delete Cascade.roots

      `for (var i = roots.length-2; i >= 0; i = i - 2) {
          debug("Running block "+i);
          Cascade.run(roots[i], roots[i+1]);
      }`

      debug "Done running Cascade.Block"

      root() for root in roots.post if roots.post

    ret

  unblockRunner = (func) ->
    roots = Cascade.roots
    delete Cascade.roots
    ret = func()
    Cascade.roots = roots
    ret

  postblockRunner = (func) ->
    if roots = Cascade.roots
      (roots.post ||= []).push func
    else
      func()
    return

  Cascade.Block = (func) ->
    if this instanceof Cascade.Block
      -> blockRunner(func)
    else
      blockRunner(func)

  # runs the function outside of the current block if there is one, then puts
  # the original block back
  Cascade.Unblock = (func) ->
    if this instanceof Cascade.Unblock
      -> unblockRunner(func)
    else
      unblockRunner(func)

  # runs the function after the current block if there is one
  Cascade.Postblock = (func) ->
    if this instanceof Cascade.Postblock
      -> postblockRunner(func)
    else
      postblockRunner(func)

  oldRun = Cascade.run

  Cascade.run = (target, source) ->
    return oldRun.call(Cascade, target, source) unless Cascade.roots

    Cascade.roots.push target, source
    debug "added #{target} to Cascade roots with source #{source} at index #{Cascade.roots.length-2}"
    return

