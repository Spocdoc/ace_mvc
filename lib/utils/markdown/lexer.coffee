block = require './block'

module.exports = class Lexer
  constructor: (@options={}) ->
    @tokens = []
    @tokens.links = {}
    @rules = block.normal

    unless @options['noGfm']
      unless @options['noTables']
        @rules = block.tables
      else
        @rules = block.gfm

  @lex: (src, options) ->
    lexer = new Lexer(options)
    lexer.lex src

  lex: (src) ->
    src = src.replace(/\r\n|\r/g, "\n").replace(/\t/g, "    ").replace(/\u00a0/g, " ").replace(/\u2424/g, "\n")
    @token src, true

  token: (src, top) ->
    src = src.replace(/^ +$/g, "")
    while src
      if cap = @rules.newline.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push type: "space"  if cap[0].length > 1
      if cap = @rules.code.exec(src)
        src = src.substring(cap[0].length)
        cap = cap[0].replace(/^ {4}/g, "")
        @tokens.push
          type: "code"
          text: (if not @options['pedantic'] then cap.replace(/\n+$/, "") else cap)

        continue
      if cap = @rules.fences.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push
          type: "code"
          lang: cap[2]
          text: cap[3]

        continue
      if cap = @rules.heading.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push
          type: "heading"
          depth: cap[1].length
          text: cap[2]

        continue
      if top and (cap = @rules.nptable.exec(src))
        src = src.substring(cap[0].length)
        item =
          type: "table"
          header: cap[1].replace(/^ *| *\| *$/g, "").split(RegExp(" *\\| *"))
          align: cap[2].replace(/^ *|\| *$/g, "").split(RegExp(" *\\| *"))
          cells: cap[3].replace(/\n$/, "").split("\n")

        i = 0
        while i < item.align.length
          if /^ *-+: *$/.test(item.align[i])
            item.align[i] = "right"
          else if /^ *:-+: *$/.test(item.align[i])
            item.align[i] = "center"
          else if /^ *:-+ *$/.test(item.align[i])
            item.align[i] = "left"
          else
            item.align[i] = null
          i++
        i = 0
        while i < item.cells.length
          item.cells[i] = item.cells[i].split(RegExp(" *\\| *"))
          i++
        @tokens.push item
        continue
      if cap = @rules.lheading.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push
          type: "heading"
          depth: (if cap[2] is "=" then 1 else 2)
          text: cap[1]

        continue
      if cap = @rules.hr.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push type: "hr"
        continue
      if cap = @rules.blockquote.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push type: "blockquote_start"
        cap = cap[0].replace(/^ *> ?/g, "")
        @token cap, top
        @tokens.push type: "blockquote_end"
        continue
      if cap = @rules.list.exec(src)
        src = src.substring(cap[0].length)
        bull = cap[2]
        @tokens.push
          type: "list_start"
          ordered: bull.length > 1

        cap = cap[0].match(@rules.item)
        next = false
        l = cap.length
        i = 0
        while i < l
          item = cap[i]
          space = item.length
          item = item.replace(/^ *([*+-]|\d+\.) +/, "")
          if ~item.indexOf("\n ")
            space -= item.length
            item = (if not @options['pedantic'] then item.replace(new RegExp("^ {1," + space + "}", "gm"), "") else item.replace(/^ {1,4}/g, ""))
          if @options['smartLists'] and i isnt l - 1
            b = block.bullet.exec(cap[i + 1])[0]
            if bull isnt b and not (bull.length > 1 and b.length > 1)
              src = cap.slice(i + 1).join("\n") + src
              i = l - 1
          loose = next or /\n\n(?!\s*$)/.test(item)
          if i isnt l - 1
            next = item[item.length - 1] is "\n"
            loose = next  unless loose
          @tokens.push type: (if loose then "loose_item_start" else "list_item_start")
          @token item, false
          @tokens.push type: "list_item_end"
          i++
        @tokens.push type: "list_end"
        continue
      if cap = @rules.html.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push
          type: (if @options['sanitize'] then "paragraph" else "html")
          pre: cap[1] is "pre" or cap[1] is "script"
          text: cap[0]

        continue
      if top and (cap = @rules.def.exec(src))
        src = src.substring(cap[0].length)
        @tokens.links[cap[1].toLowerCase()] =
          href: cap[2]
          title: cap[3]

        continue
      if top and (cap = @rules.table.exec(src))
        src = src.substring(cap[0].length)
        item =
          type: "table"
          header: cap[1].replace(/^ *| *\| *$/g, "").split(RegExp(" *\\| *"))
          align: cap[2].replace(/^ *|\| *$/g, "").split(RegExp(" *\\| *"))
          cells: cap[3].replace(/(?: *\| *)?\n$/, "").split("\n")

        i = 0
        while i < item.align.length
          if /^ *-+: *$/.test(item.align[i])
            item.align[i] = "right"
          else if /^ *:-+: *$/.test(item.align[i])
            item.align[i] = "center"
          else if /^ *:-+ *$/.test(item.align[i])
            item.align[i] = "left"
          else
            item.align[i] = null
          i++
        i = 0
        while i < item.cells.length
          item.cells[i] = item.cells[i].replace(/^ *\| *| *\| *$/g, "").split(RegExp(" *\\| *"))
          i++
        @tokens.push item
        continue
      if top and (cap = @rules.paragraph.exec(src))
        src = src.substring(cap[0].length)
        @tokens.push
          type: "paragraph"
          text: (if cap[1][cap[1].length - 1] is "\n" then cap[1].slice(0, -1) else cap[1])

        continue
      if cap = @rules.text.exec(src)
        src = src.substring(cap[0].length)
        @tokens.push
          type: "text"
          text: cap[0]

        continue
      throw new Error("Infinite loop on byte: " + src.charCodeAt(0))  if src
    @tokens

