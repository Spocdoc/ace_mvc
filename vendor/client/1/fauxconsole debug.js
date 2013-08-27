if (!window.console) {

    var unsafeEscape = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;'
    };

    var unsafeHtmlEscape = (function() {
      var escapeChar = function(ch) {
        return unsafeEscape[ch] || ch;
      };
      return function(text) {
        return text.replace(/[&<>]/g, escapeChar);
      };
    })();

    var console = {
        init: function() {
            console.d = document.createElement('div');
            document.body.appendChild(console.d);
            var a = document.createElement('a');
            a.href = 'javascript:console.hide()';
            a.innerHTML = 'close';
            console.d.appendChild(a);
            var a = document.createElement('a');
            a.href = 'javascript:console.clear();';
            a.innerHTML = 'clear';
            console.d.appendChild(a);
            var id = 'fauxconsole';
            if (!document.getElementById(id)) {
                console.d.id = id;
            }
            console.hide();
        },
        hide: function() {
            console.d.style.display = 'none';
        },
        show: function() {
            console.d.style.display = 'block';
        },
        log: function(o) {
            console.d.innerHTML += '<br/>';
            var arg;
            for (var i = 0; i < arguments.length; ++i) {
              if (i > 0) console.d.innerHTML += ", ";
              try {
                if (null == (arg = arguments[i])) {
                  console.d.innerHTML += arg;
                } else {
                  console.d.innerHTML += unsafeHtmlEscape(JSON.stringify(arg));
                }
              } catch (_error) {
                alert(''+_error);
              }
            }
            console.show();
        },
        clear: function() {
            console.d.parentNode.removeChild(console.d);
            console.init();
            console.show();
        }
    };
    console.init();
}
