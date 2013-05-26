module.exports = (self, syms) ->
  self[name] = v for mangle,name of syms when (v = self[mangle])?
  return
