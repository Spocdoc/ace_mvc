module.exports =
  makeClassName: do ->
    charsRegex = /[^A-Za-z0-9-_]/g
    startRegex = /^[^A-Za-z]+/
    (name) ->
      name.replace('/', '-')
        .replace(' ', '_')
        .replace(charsRegex,'')
        .replace(startRegex,'')

