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

_.argNames = do ->
  regexComments = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
  regexFunction = /^function\s*[^\(]*\(([^\)]*)\)\s*\{([\s\S]*)\}$/m
  regexTrim = /^\s*|\s*$/mg
  regexTrimCommas = /\s*,\s*/mg

  return (fn) ->
    fnText = Function.toString.apply(fn).replace(regexComments, '')
    argsBody = fnText.match(regexFunction)
    if str = argsBody[1].replace(regexTrim,'').replace(regexTrimCommas,',')
      str.split ','
    else
      []
