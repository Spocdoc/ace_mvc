// from lodash
module.exports.debounce = function (func, wait, immediate) {
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
};

