global.digest = (str) ->
   require('crypto').createHash('sha1').update(str).digest("hex")
