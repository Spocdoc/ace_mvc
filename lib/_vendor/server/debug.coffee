# inspired by <https://github.com/visionmedia/debug>
tty = require 'tty'

isatty = tty.isatty(2)
env = process.env

COLORS = [2,4,6,3,5,12,13,1,14]
colors = {
  red: 1
  green: 2
  yellow: 3
  blue: 4
  magenta: 5
  cyan: 6
  white: 7
  default: 8
  RED: 9
  GREEN: 10
  YELLOW: 11
  BLUE: 12
  MAGENTA: 13
  CYAN: 14
  WHITE: 15
  BLACK: 16
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
  _lastColor = -1
  (name) ->
    _colors[name] ||= COLORS[++_lastColor % COLORS.length]

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
