module.exports = crc32 = (str) ->
  # from es-hash
  `
        //str = String(s);
        var c=0, i=0, j=0;
        var polynomial = arguments.length < 2 ? 0x04C11DB7 : arguments[1],
            initialValue = arguments.length < 3 ? 0xFFFFFFFF : arguments[2],
            finalXORValue = arguments.length < 4 ? 0xFFFFFFFF : arguments[3],
            crc = initialValue,
            table = [], i, j, c;

        function reverse(x, n) {
            var b = 0;
            while (n) {
                b = b * 2 + x % 2;
                x /= 2;
                x -= x % 1;
                n--;
            }
            return b;
        }

        var range = 255, c=0;
        for (i = 0; i < str.length; i++){
            c = str.charCodeAt(i);
            if(c>range){ range=c; }
        }

        for (i = range; i >= 0; i--) {
            c = reverse(i, 32);

            for (j = 0; j < 8; j++) {
                c = ((c * 2) ^ (((c >>> 31) % 2) * polynomial)) >>> 0;
            }

            table[i] = reverse(c, 32);
        }

        for (i = 0; i < str.length; i++) {
            c = str.charCodeAt(i);
            if (c > range) {
                throw new RangeError();
            }
            j = (crc % 256) ^ c;
            crc = ((crc / 256) ^ table[j]) >>> 0;
        }

        return (crc ^ finalXORValue) >>> 0;
    `
  return


