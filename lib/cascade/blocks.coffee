debug = global.debug 'ace:cascade:block'

module.exports = (Cascade) ->

  blockRunner = (func) ->
    if Cascade.roots
      ret = func()
    else
      Cascade.roots = []
      unless Cascade.post
        post = Cascade.post = []

      debug "Building up Cascade.Block"

      ret = func()

      debug "Running Cascade.Block..."

      roots = Cascade.roots
      Cascade.roots = null

      `for (var i = roots.length-2; i >= 0; i = i - 2) {
          debug("Running block "+i);
          Cascade.run(roots[i], roots[i+1]);
      }`

      debug "Running post block"

      Cascade.post = null
      root() for root in post if post

      debug "Done running Cascade.Block"

    ret

  unblockRunner = (func) ->
    roots = Cascade.roots
    Cascade.roots = null
    ret = func()
    Cascade.roots = roots
    ret

  postblockRunner = (func) ->
    if post = Cascade.post
      post.push func
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

