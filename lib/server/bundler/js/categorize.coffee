path = require 'path'
regexNonSpace = /\S+/g

output = null
allCategories = null
categoryIncludes = null
standard = null
nonstandard = null

setIncludes = do ->
  regex = /^(-)?(\w+?)([<>][=]?)?(\d+)?$/
  NEG = 1
  CAT = 2
  OP = 3
  NUM = 4
  (categoryIncludes, word) ->
    return unless m = regex.exec word
    catMatch = new RegExp "^#{RegExp.escape m[CAT]}(\\d+)?$"
    if m[NUM]
      unless m[OP]
        opMatch = (num) -> num is m[NUM]
      else
        opMatch = (num) -> eval "#{num} #{m[OP]} #{m[NUM]}"

    for category, current of categoryIncludes
      matches = (n = catMatch.exec category) and (!m[NUM]? or opMatch? n[1])
      if m[NEG]
        categoryIncludes[category] = 0 if matches
      else
        categoryIncludes[category] = (current ? true) and !!matches
    return

addFilePath = (debugReleaseObj, categoryIncludes, filePath) ->
  for category, arr of debugReleaseObj when categoryIncludes[category]
    arr.push filePath
  return

categorize = (filePath) ->
  words = (path.basename filePath, path.extname filePath).match regexNonSpace
  categoryIncludes[category] = null for category in allCategories

  for word, i in words
    if word is 'debug'
      mode = 'debug'
    else if word is 'release'
      mode = release
    else if i > 0
      setIncludes categoryIncludes, word

  categoryIncludes[category] ?= 1 for category in standard

  addFilePath output.debug, categoryIncludes, filePath unless mode is 'release'
  addFilePath output.release, categoryIncludes, filePath unless mode is 'debug'
  return

module.exports = (categories, filePaths) ->
  output =
    debug: {}
    release: {}

  categories ||= {}
  categories.standard ||= []
  categories.nonstandard ||= []

  throw new Error "Bundler: can't use 'standard' as a category" if categories.standard.standard or categories.nonstandard.standard

  standard = categories.standard.concat ['standard']
  {nonstandard} = categories
  allCategories = standard.concat nonstandard
  categoryIncludes = {}

  for category in allCategories
    output.debug[category] = []
    output.release[category] = []

  categorize filePath for filePath in filePaths
  output

