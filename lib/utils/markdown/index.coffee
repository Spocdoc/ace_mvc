_ = require '../u'
Parser = require './parser'
Lexer = require './lexer'
InlineLexer = require './inline_lexer'

noOptions = {}

###
marked.defaults =
  noGfm: false
  noTables: false
  breaks: false
  pedantic: false
  sanitize: false
  smartLists: false
  silent: false
  smartypants: false
###

module.exports = marked = (src, options=noOptions) ->
  try
    Parser.parse(Lexer.lex(src, options), options)
  catch _error
    if options?['silent']
      return "<p>An error occured:</p><pre>" + _.unsafeHtmlEscape(_error.message) + "</pre>"
    else
      throw _error

marked['parser'] = marked.parser = Parser.parse
marked['lexer'] = marked.lexer = Lexer.lex
marked['inlineLexer'] = marked.inlineLexer = InlineLexer.output
marked['parse'] = marked.parse = marked
