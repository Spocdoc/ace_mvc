module.exports = (Cascade) ->

  blockRunner = (func) ->
    if Cascade.roots
      ret = func()
    else
      Cascade.roots = []

      ret = func()

      roots = Cascade.roots
      delete Cascade.roots

      for root in roots
        if root instanceof Cascade
          root._calculate(false)
        else if typeof root is 'function'
          root()

      if roots.post
        for root in roots.post
          if root instanceof Cascade
            root._calculate(false)
          else if typeof root is 'function'
            root()

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
  Cascade.Unblock: (func) ->
    if this instanceof Cascade.Unblock
      -> unblockRunner(func)
    else
      unblockRunner(func)

  # runs the function after the current block if there is one
  Cascade.Postblock: (func) ->
    if this instanceof Cascade.Postblock
      -> postblockRunner(func)
    else
      postblockRunner(func)
