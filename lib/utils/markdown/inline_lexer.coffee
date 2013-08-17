inline = require './inline'

module.exports = class InlineLexer
  constructor: (@links, @options={}) ->
    @rules = inline.normal
    throw new Error("Tokens array requires a `links` property.")  unless @links
    unless @options['noGfm']
      if @options['breaks']
        @rules = inline.breaks
      else
        @rules = inline.gfm
    else @rules = inline.pedantic  if @options['pedantic']

  @output: (src, links, options) ->
    inline = new InlineLexer(links, options)
    inline.output src

  outputLink: (cap, link) ->
    if cap[0][0] isnt "!"
      "<a href=\"" + escape(link.href) + "\"" + ((if link.title then " title=\"" + escape(link.title) + "\"" else "")) + ">" + @output(cap[1]) + "</a>"
    else
      "<img src=\"" + escape(link.href) + "\" alt=\"" + escape(cap[1]) + "\"" + ((if link.title then " title=\"" + escape(link.title) + "\"" else "")) + ">"

  smartypants: (text) ->
    return text  unless @options['smartypants']
    text.replace(/--/g, "—").replace(/'([^']*)'/g, "‘$1’").replace(/"([^"]*)"/g, "“$1”").replace /\.{3}/g, "…"

  mangle: (text) ->
    out = ""
    l = text.length
    i = 0
    ch = undefined
    while i < l
      ch = text.charCodeAt(i)
      ch = "x" + ch.toString(16)  if Math.random() > 0.5
      out += "&#" + ch + ";"
      i++
    out

  output: (src) ->
    out = ""
    link = undefined
    text = undefined
    href = undefined
    cap = undefined
    while src
      if cap = @rules.escape.exec(src)
        src = src.substring(cap[0].length)
        out += cap[1]
        continue
      if cap = @rules.autolink.exec(src)
        src = src.substring(cap[0].length)
        if cap[2] is "@"
          text = (if cap[1][6] is ":" then @mangle(cap[1].substring(7)) else @mangle(cap[1]))
          href = @mangle("mailto:") + text
        else
          text = escape(cap[1])
          href = text
        out += "<a href=\"" + href + "\">" + text + "</a>"
        continue
      if cap = @rules.url.exec(src)
        src = src.substring(cap[0].length)
        text = escape(cap[1])
        href = text
        out += "<a href=\"" + href + "\">" + text + "</a>"
        continue
      if cap = @rules.tag.exec(src)
        src = src.substring(cap[0].length)
        out += (if @options['sanitize'] then escape(cap[0]) else cap[0])
        continue
      if cap = @rules.link.exec(src)
        src = src.substring(cap[0].length)
        out += @outputLink(cap,
          href: cap[2]
          title: cap[3]
        )
        continue
      if (cap = @rules.reflink.exec(src)) or (cap = @rules.nolink.exec(src))
        src = src.substring(cap[0].length)
        link = (cap[2] or cap[1]).replace(/\s+/g, " ")
        link = @links[link.toLowerCase()]
        if not link or not link.href
          out += cap[0][0]
          src = cap[0].substring(1) + src
          continue
        out += @outputLink(cap, link)
        continue
      if cap = @rules.strong.exec(src)
        src = src.substring(cap[0].length)
        out += "<strong>" + @output(cap[2] or cap[1]) + "</strong>"
        continue
      if cap = @rules.em.exec(src)
        src = src.substring(cap[0].length)
        out += "<em>" + @output(cap[2] or cap[1]) + "</em>"
        continue
      if cap = @rules.code.exec(src)
        src = src.substring(cap[0].length)
        out += "<code>" + escape(cap[2], true) + "</code>"
        continue
      if cap = @rules.br.exec(src)
        src = src.substring(cap[0].length)
        out += "<br>"
        continue
      if cap = @rules.del.exec(src)
        src = src.substring(cap[0].length)
        out += "<del>" + @output(cap[1]) + "</del>"
        continue
      if cap = @rules.text.exec(src)
        src = src.substring(cap[0].length)
        out += escape(@smartypants(cap[0]))
        continue
      throw new Error("Infinite loop on byte: " + src.charCodeAt(0))  if src
    out

