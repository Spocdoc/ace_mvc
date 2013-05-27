# inspired by <https://github.com/visionmedia/debug>
tty = require 'tty'
crc32 = require './crc32'

isatty = tty.isatty(2)
env = process.env

COLORS = [1..8]
colors = {
  red: 1
  green: 2
  blue: 3
  magenta: 4
  cyan: 5
  white: 6
  default: 7
  RED: 8
  GREEN: 9
  YELLOW: 10
  BLUE: 11
  MAGENTA: 12
  CYAN: 13
  WHITE: 14
  BLACK: 15
}

includes = []
excludes = []
spaces = "                                                            "

for name in (env.DEBUG || '').split(/[\s,]+/)
  name = name.replace("*", ".*?")
  if name[0] is "-"
    excludes.push new RegExp("^" + name.substr(1) + "$")
  else
    includes.push new RegExp("^" + name + "$")

getColor = do ->
  _colors = {}
  (name) ->
    _colors[name] ||= COLORS[crc32(name) % COLORS.length]

color = (str, color) ->
  "\u001b[38;5;#{color}m#{str}\u001b[0m"

noop = ->

duration = do ->
  _start = Date.now()
  ->
    Date.now() - _start

module.exports = global.debug = (name) ->
  match = (re) -> re.test name
  return noop if excludes.some(match) or !includes.some(match)

  nameStr = name
  nameStr += spaces.substr(0,25 - nameStr.length)
  nameStr = color(nameStr, getColor(name))

  if isatty or env.DEBUG_COLORS
    (fmt) ->
      msStr = "#{duration()} ms"
      msStr += spaces.substr(0,11 - msStr.length)

      fmt = color(msStr,colors.default) + nameStr + " " + (fmt||"")
      console.error.apply this, arguments
  else
    (fmt) ->
      fmt = new Date().toUTCString() + " " + name + " " + (fmt||"")
      console.error.apply this, arguments
