InlineLexer = require './inline_lexer'

module.exports = class Parser
  constructor: (@options={}) ->
    @tokens = []
    @token = null

  @parse: (src, options) ->
    parser = new Parser(options)
    parser.parse src

  parse: (src) ->
    @inline = new InlineLexer(src.links, @options)
    @tokens = src.reverse()
    out = ""
    out += @tok()  while @next()
    out

  next: ->
    @token = @tokens.pop()

  peek: ->
    @tokens[@tokens.length - 1] or 0

  parseText: ->
    body = @token.text
    body += "\n" + @next().text  while @peek().type is "text"
    @inline.output body

  tok: ->
    switch @token.type
      when "space"
        ""
      when "hr"
        "<hr>\n"
      when "heading"
        "<h" + @token.depth + ">" + @inline.output(@token.text) + "</h" + @token.depth + ">\n"
      when "code"
        @token.text = escape(@token.text, true)  unless @token.escaped
        "<pre><code" + ((if @token.lang then " class=\"lang-" + @token.lang + "\"" else "")) + ">" + @token.text + "</code></pre>\n"
      when "table"
        body = ""
        heading = undefined
        i = undefined
        row = undefined
        cell = undefined
        j = undefined
        body += "<thead>\n<tr>\n"
        i = 0
        while i < @token.header.length
          heading = @inline.output(@token.header[i])
          body += (if @token.align[i] then "<th align=\"" + @token.align[i] + "\">" + heading + "</th>\n" else "<th>" + heading + "</th>\n")
          i++
        body += "</tr>\n</thead>\n"
        body += "<tbody>\n"
        i = 0
        while i < @token.cells.length
          row = @token.cells[i]
          body += "<tr>\n"
          j = 0
          while j < row.length
            cell = @inline.output(row[j])
            body += (if @token.align[j] then "<td align=\"" + @token.align[j] + "\">" + cell + "</td>\n" else "<td>" + cell + "</td>\n")
            j++
          body += "</tr>\n"
          i++
        body += "</tbody>\n"
        "<table>\n" + body + "</table>\n"
      when "blockquote_start"
        body = ""
        body += @tok()  while @next().type isnt "blockquote_end"
        "<blockquote>\n" + body + "</blockquote>\n"
      when "list_start"
        type = (if @token.ordered then "ol" else "ul")
        body = ""
        body += @tok()  while @next().type isnt "list_end"
        "<" + type + ">\n" + body + "</" + type + ">\n"
      when "list_item_start"
        body = ""
        body += (if @token.type is "text" then @parseText() else @tok())  while @next().type isnt "list_item_end"
        "<li>" + body + "</li>\n"
      when "loose_item_start"
        body = ""
        body += @tok()  while @next().type isnt "list_item_end"
        "<li>" + body + "</li>\n"
      when "html"
        (if not @token.pre and not @options['pedantic'] then @inline.output(@token.text) else @token.text)
      when "paragraph"
        "<p>" + @inline.output(@token.text) + "</p>\n"
      when "text"
        "<p>" + @parseText() + "</p>\n"

