Outlet = lib 'index'

describe 'Outlet', ->
  describe 'values', ->
    it 'should have initial value', ->
      a = new Outlet 42
      expect(a.value).eq 42
      expect(a.get()).eq 42

  describe 'equal outlet', ->
    it 'should have the same value', ->
      a = new Outlet 42
      b = new Outlet a
      expect(b.value).eq 42
      expect(b.get()).eq 42

  describe 'cascade', ->
    it 'should set equal outlets immediately', ->
      a = new Outlet 42
      b = new Outlet a
      a.set 44
      expect(b.value).eq 44

    it 'should update auto outflows', ->
      a = new Outlet 42
      b = new Outlet a

      calls = 0

      fn = ->
        ++calls
        b.get()

      c = new Outlet fn, null, true
      expect(c.value).eq 42
      expect(calls).eq 1

      a.set 43
      expect(c.value).eq 43
      expect(calls).eq 2

  describe 'argument name dependencies', ->
    it 'should call automatically', ->
      ctx =
        a: new Outlet 42
        b: new Outlet 43

      calls = 0

      fn = (a,b) ->
        ++calls
        a + b

      c = new Outlet fn, ctx

      expect(calls).eq 1
      expect(c.value).eq 42+43

      ctx.a.set 44

      expect(calls).eq 2
      expect(c.value).eq 44+43

    describe 'blocks', ->
      it 'should call outflows only once when multiple auto inflows change', ->
        ctx =
          a: new Outlet 42
          b: new Outlet 43

        calls = 0

        fn = (a,b) ->
          ++calls
          a + b

        c = new Outlet fn, ctx

        expect(calls).eq 1
        expect(c.value).eq 42+43

        ctx.a.set 44
        ctx.b.set 45

        expect(calls).eq 3
        expect(c.value).eq 44+45

        Outlet.openBlock()
        ctx.a.set 45
        ctx.b.set 46
        Outlet.closeBlock()

        expect(calls).eq 4
        expect(c.value).eq 45+46

  describe 'outlet-valued function', ->
    it 'should proxy the outlet', ->
      arr = [
        new Outlet 1
        new Outlet 2
      ]
      which = new Outlet 0

      calls = 0

      b = new Outlet (->
        ++calls
        arr[which.get()]), null, true

      expect(calls).eq 1
      expect(b.value).eq 1

      which.set 1
      expect(calls).eq 2
      expect(b.value).eq 2

      arr[1].set 43

      expect(calls).eq 2
      expect(b.value).eq 43

      b.set 44
      expect(calls).eq 2
      expect(arr[0].value).eq 1
      expect(arr[1].value).eq 44

  describe 'auto inflows', ->
    it 'should remove auto inflows when they don\'t apply', ->
      a = new Outlet true
      b = new Outlet 1
      c = new Outlet 2

      calls = 0

      d = new Outlet (->
        ++calls
        if a.get()
          2 * b.get()
        else
          2 * c.get()
      ), null, true

      expect(calls).eq 1
      expect(d.value).eq 2*1

      c.set 3
      expect(calls).eq 1
      expect(d.value).eq 2*1

      b.set 4
      expect(calls).eq 2
      expect(d.value).eq 2*4

      a.set false
      expect(calls).eq 3
      expect(d.value).eq 2*3

      b.set 5
      expect(calls).eq 3
      expect(d.value).eq 2*3

      c.set 6
      expect(calls).eq 4
      expect(d.value).eq 2*6

  describe 'more complex dependencies', ->
    it 'should handle route example', ->
      a = new Outlet 3
      b = new Outlet -> 1
      c = new Outlet -> a.value * 2

      a.addOutflow b
      a.addOutflow c
      b.addOutflow c

      expect(a.value).eq 3
      expect(b.value).eq 1
      expect(c.value).eq 3 * 2

      a.set 4
      expect(a.value).eq 4
      expect(b.value).eq 1
      expect(c.value).eq 4 * 2

    it 'should handle changing bridge example', ->
      f = new Outlet 1
      e = new Outlet 2
      d = new Outlet (-> 2 * e.get()), null, true
      c = new Outlet d
      g = new Outlet 42
      b = new Outlet (->
        if f.get()
          c
        else
          g
      ), null, true
      a = new Outlet b

      expect(f.value).eq 1
      expect(e.value).eq 2
      expect(d.value).eq 2*2
      expect(c.value).eq d.value
      expect(b.value).eq c.value
      expect(a.value).eq b.value

      e.set 3

      expect(f.value).eq 1
      expect(e.value).eq 3
      expect(d.value).eq 2*3
      expect(c.value).eq d.value
      expect(b.value).eq c.value
      expect(a.value).eq b.value

      Outlet.openBlock()
      e.set 4
      f.set 0
      Outlet.closeBlock()

      expect(f.value).eq 0
      expect(e.value).eq 4
      expect(d.value).eq 2*4
      expect(c.value).eq d.value
      expect(b.value).eq g.value
      expect(a.value).eq b.value

    it 'should allow changing the value and the proxy in the same block', ->
      a = new Outlet first = {foo: new Outlet 42}

      b = new Outlet (-> 2*first.foo.get()), null, true

      proxy = new Outlet 0, null, true
      proxy.set -> a.get().foo

      expect(proxy.value).eq 42
      a.set second = {foo: new Outlet 43}
      expect(proxy.value).eq 43

      Outlet.openBlock()
      a.set first
      proxy.set 44
      Outlet.closeBlock()

      expect(first.foo.value).eq 44
      expect(second.foo.value).eq 43
      expect(proxy.value).eq 44
      expect(b.value).eq 88

      Outlet.openBlock()
      proxy.set 45
      a.set second
      Outlet.closeBlock()

      expect(first.foo.value).eq 45
      expect(second.foo.value).eq 43
      expect(proxy.value).eq 43

    it 'should allow changing the value and the proxy in the same block via a function', ->

      content = new Outlet 0, null, true
      view = new Outlet 0, null, true
      error = new Outlet 0, null, true

      error.set -> content.get()?.outlets.error
      aView = outlets: error: new Outlet 42

      Outlet.block ->
        content.set aView
        error.set 45
      expect(aView.outlets.error.value).eq 45


  ###
  describe 'interrupts', ->
    it 'should keep the interrupted calc pending and add it as an outflow', ->
      a = new Outlet 1
      b = new Outlet (-> a.get()), null, true

      Outlet.openBlock()
      a.set 43
      expect(b.pending).true
      expect(!!a.pending).false
      c = new Outlet (->
        2 * b.get()
      ), null, true
      expect(c.value).eq undefined
      expect(c.pending).true
      Outlet.closeBlock()

      expect(c.value).eq 2*43

    it 'should not interrupt outlets that don\'t have auto dependencies', ->
      a = new Outlet 1
      b = new Outlet (-> a.get()), null, true

      Outlet.openBlock()
      a.set 43
      expect(b.pending).true
      expect(!!a.pending).false
      c = new Outlet (->
        2 * b.get()
      ), null, false
      expect(!!c.pending).false
      expect(c.value).eq NaN
      Outlet.closeBlock()

      expect(c.value).eq 2*43
  ###



