Emitter =
  on: (event, fn, ctx) ->
    @_emitter ?= {}
    (@_emitter[event] ||= []).push
      fn: fn
      ctx: ctx
    return this

  # any of name, callback and context can be specified to remove event
  # listeners matching the condition
  off: (event, fn, ctx) ->
    `var c;
    if (!this._emitter) return;
    if (event) {
      var events = this._emitter[event], j = [], a = 0, b;
      if (!events) return;
      for (b = events.length; a < b; a++) {
        c = events[a], ((fn && c.fn !== fn) || (ctx && c.ctx !== ctx)) && j.push(c);
      }
      if (j.length) this._emitter[event] = j;
      else delete this._emitter[event];
    } else {
      if (!fn && !ctx) {
        delete this._emitter;
      } else {
        for (c in this._emitter) {
          this.off(c, fn, ctx);
        }
      }
    }`
    return this

  emit: (event, a1, a2, a3) ->
    # use Backbone's optimization (slightly modified)
    `var events, ev, i = -1, l;
    if (!this._emitter) return;
    if (!(events = this._emitter[event])) return;
    l = events.length;
    switch (arguments.length) {
      case 1: while (++i < l) (ev = events[i]).fn.call(ev.ctx); return;
      case 2: while (++i < l) (ev = events[i]).fn.call(ev.ctx, a1); return;
      case 3: while (++i < l) (ev = events[i]).fn.call(ev.ctx, a1, a2); return;
      case 4: while (++i < l) (ev = events[i]).fn.call(ev.ctx, a1, a2, a3); return;
      default: while (++i < l) (ev = events[i]).fn.apply(ev.ctx, [].slice.call(arguments, 1));
    }`
    return

module.exports = Emitter

