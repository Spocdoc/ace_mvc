{merge, replace, escape} = require './utils'
noop = ->

module.exports = inline =
  escape: /^\\([\\`*{}\[\]()#+\-.!_>])/
  autolink: /^<([^ >]+(@|:\/)[^ >]+)>/
  url: noop
  tag: /^<!--[\s\S]*?-->|^<\/?\w+(?:"[^"]*"|'[^']*'|[^'">])*?>/
  link: /^!?\[(inside)\]\(href\)/
  reflink: /^!?\[(inside)\]\s*\[([^\]]*)\]/
  nolink: /^!?\[((?:\[[^\]]*\]|[^\[\]])*)\]/
  strong: /^__([\s\S]+?)__(?!_)|^\*\*([\s\S]+?)\*\*(?!\*)/
  em: /^\b_((?:__|[\s\S])+?)_\b|^\*((?:\*\*|[\s\S])+?)\*(?!\*)/
  code: /^(`+)\s*([\s\S]*?[^`])\s*\1(?!`)/
  br: /^ {2,}\n(?!\s*$)/
  del: noop
  text: /^[\s\S]+?(?=[\\<!\[_*`]| {2,}\n|$)/

inline._inside = /(?:\[[^\]]*\]|[^\]]|\](?=[^\[]*\]))*/
inline._href = /\s*<?([^\s]*?)>?(?:\s+['"]([\s\S]*?)['"])?\s*/
inline.link = replace(inline.link)("inside", inline._inside)("href", inline._href)()
inline.reflink = replace(inline.reflink)("inside", inline._inside)()
inline.normal = merge({}, inline)
inline.pedantic = merge({}, inline.normal,
  strong: /^__(?=\S)([\s\S]*?\S)__(?!_)|^\*\*(?=\S)([\s\S]*?\S)\*\*(?!\*)/
  em: /^_(?=\S)([\s\S]*?\S)_(?!_)|^\*(?=\S)([\s\S]*?\S)\*(?!\*)/
)
inline.gfm = merge({}, inline.normal,
  escape: replace(inline.escape)("])", "~|])")()
  url: /^(https?:\/\/[^\s<]+[^<.,:;"')\]\s])/
  del: /^~~(?=\S)([\s\S]*?\S)~~/
  text: replace(inline.text)("]|", "~]|")("|", "|https?://|")()
)
inline.breaks = merge({}, inline.gfm,
  br: replace(inline.br)("{2,}", "*")()
  text: replace(inline.gfm.text)("{2,}", "*")()
)
