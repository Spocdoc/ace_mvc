# stylus

 - write a function for max-height, etc. that uses IE expressions to support IE<8

     example: 

        max-height: 5em;
        _height:unquote('expression(this.scrollHeight > 5 * parseInt(this.currentStyle.fontSize, 10) ?  "5em" : "auto");')


