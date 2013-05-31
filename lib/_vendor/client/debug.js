// <https://github.com/visionmedia/debug>

(function () {
  var includes = [],
      excludes = [],
      spaces = "                                                            ",
      noop = function () {},
      debug;

  var duration = (function() {
    var _start;

    _start = (new Date()).getTime();
    return function() {
      return (new Date).getTime() - _start;
    };
  })();

  window.debug = debug = function (name) {
    if (!debug.enabled(name)) return noop;

    var nameStr = name;
    nameStr += spaces.substr(0, 25 - nameStr.length);

    return function (fmt) {
      var msStr;

      msStr = "" + (duration()) + " ms";
      msStr += spaces.substr(0, 11 - msStr.length);

      fmt = msStr + nameStr + ' ' + fmt;

      // This hackery is required for IE8
      // where `console.log` doesn't have 'apply'
      window.console
        && console.log
        && Function.prototype.apply.call(console.log, console, arguments);
    };
  };

  debug.enable = function(name) {
    try {
      localStorage.debug = name;
    } catch(e){}

    var split = (name || '').split(/[\s,]+/)
      , len = split.length;

    for (var i = 0; i < len; i++) {
      name = split[i].replace('*', '.*?');
      if (name[0] === '-') {
        excludes.push(new RegExp('^' + name.substr(1) + '$'));
      }
      else {
        includes.push(new RegExp('^' + name + '$'));
      }
    }
  };

  /**
   * Disable debug output.
   *
   * @api public
   */

  debug.disable = function(){
    debug.enable('');
  };

  /**
   * Returns true if the given mode name is enabled, false otherwise.
   *
   * @param {String} name
   * @return {Boolean}
   * @api public
   */

  debug.enabled = function(name) {
    for (var i = 0, len = excludes.length; i < len; i++) {
      if (excludes[i].test(name)) {
        return false;
      }
    }
    for (var i = 0, len = includes.length; i < len; i++) {
      if (includes[i].test(name)) {
        return true;
      }
    }
    return false;
  };

  // persist

  if (window.localStorage && window.localStorage.debug) {
    debug.enable(localStorage.debug);
  } else if (window.DEBUG) {
    debug.enable(window.DEBUG);
  }
})();
