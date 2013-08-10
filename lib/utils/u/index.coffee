module.exports = _ = {}

# from lodash
_.debounce = `function (func, wait, immediate) {
  var args,
      result,
      thisArg,
      timeoutId;

  function delayed() {
    timeoutId = null;
    if (!immediate) {
      result = func.apply(thisArg, args);
    }
  }
  return function() {
    var isImmediate = immediate && !timeoutId;
    args = arguments;
    thisArg = this;

    clearTimeout(timeoutId);
    timeoutId = setTimeout(delayed, wait);

    if (isImmediate) {
      result = func.apply(thisArg, args);
    }
    return result;
  };
}`

_.throttle = `function (func, wait) {
  var args,
      result,
      thisArg,
      lastCalled = 0,
      timeoutId = null;

  function trailingCall() {
    lastCalled = new Date;
    timeoutId = null;
    result = func.apply(thisArg, args);
  }
  return function() {
    var now = new Date,
        remaining = wait - (now - lastCalled);

    args = arguments;
    thisArg = this;

    if (remaining <= 0) {
      clearTimeout(timeoutId);
      timeoutId = null;
      lastCalled = now;
      result = func.apply(thisArg, args);
    }
    else if (!timeoutId) {
      timeoutId = setTimeout(trailingCall, remaining);
    }
    return result;
  };
}`

_.argNames = do ->
  regexComments = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
  regexFunction = /^function\s*[^\(]*\(([^\)]*)\)\s*\{([\s\S]*)\}$/m
  regexTrim = /^\s*|\s*$/mg
  regexTrimCommas = /\s*,\s*/mg

  return (fn) ->
    if fn.length
      fnText = Function.toString.apply(fn).replace(regexComments, '')
      argsBody = fnText.match(regexFunction)
      argsBody[1].replace(regexTrim,'').replace(regexTrimCommas,',').split ','
    else
      []

unsafeEscape =
 '&': '&amp;',
 '<': '&lt;',
 '>': '&gt;'

_.unsafeHtmlEscape = do ->
  escapeChar = (char) -> unsafeEscape[char] || char
  (text) ->
    text.replace /[&<>]/g, escapeChar

_.htmlEscape = do ->
  p = global.$ '<p>'
  (text) ->
    p.text(text).html()

