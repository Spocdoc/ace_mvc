HistoryOutlets = lib 'history_outlets'
OutletMethod = lib '../cascade/outlet_method'
Snapshots = lib 'snapshots'
snapshotTests = require './snapshots'
Cascade = lib '../cascade/cascade'

Outlet = lib '../cascade/outlet'

describe 'HistoryOutlets', ->
  describe 'Snapshots tests', ->
    snapshotTests HistoryOutlets

  describe 'basics', ->
    beforeEach ->
      @a = new HistoryOutlets

    it 'should have an index', ->
      expect(@a[0].index).eq 0

    it 'should have an index 1 after another push', ->
      @a.push()
      expect(@a[1].index).eq 1

    it 'should have \'to\' set to the the first index', ->
      expect(@a.to).eq @a[0]

    it 'should have \'from\' index set to -1', ->
      expect(@a.from.index).eq -1

  describe '#get', ->
    beforeEach ->
      @a = new HistoryOutlets

    it 'should return an Outlet', ->
      ret = @a.to.get(['a','b','c'])
      expect(ret).instanceof Outlet

    it 'should return a HistoryOutlet at the appropriate path', ->
      ret = @a.to.get(['a','b','c'])
      ret.set(42)
      expect(@a.to.a.b.c.get()).eq 42

    it 'should return the same outlet when fetched multiple times', ->
      outlet = @a.to.get(['a','b','c'])
      expect(outlet).to.exist
      outlet2 = @a.to.get(['a','b','c'])
      expect(outlet).eq outlet2

  describe 'HistoryOutlet', ->
    beforeEach ->
      @a = new HistoryOutlets

    it 'should set data locally', ->
      @a.to.get(['controller','prop']).set(42)
      @a.navigate()
      @a.to.get(['controller','prop']).set(43)
      expect(@a.from.get(['controller','prop']).get()).eq 42
      expect(@a.to.controller.prop.get()).eq 43

  describe '#navigate', ->
    beforeEach ->
      @a = new HistoryOutlets

    it 'should set \'to\' to the next index and \'from\' to the previous \'to\'', ->
      expect(@a.to).eq @a[0]
      expect(@a.from.index).eq -1
      @a.navigate()
      expect(@a.to.index).eq 1
      expect(@a.from.index).eq 0

    it 'should restore values when navigating back', ->
      @a.to.get(['controller','delegate']).set(42)
      @a.navigate()
      @a.to.get(['controller','delegate']).set(43)
      expect(@a.to.controller.delegate.get()).eq 43
      @a.navigate(0)
      expect(@a.to.controller.delegate.get()).eq 42

    it 'should call outflows when navigating back and forth', ->
      x = new Outlet 42
      out = new Outlet foo = sinon.spy -> x.get()
      expect(foo).calledOnce
      @a.to.get(['controller','delegate']).set(out)
      @a.navigate()
      expect(@a.to.controller.delegate.get()).eq 42
      x.set(43)
      expect(foo).calledTwice
      expect(@a.to.controller.delegate.get()).eq 43
      @a.navigate(0)
      expect(out.get()).eq 42
      expect(@a.to.controller.delegate.get()).eq 42
      @a.navigate(1)
      expect(out.get()).eq 43
      expect(@a.to.controller.delegate.get()).eq 43

    it 'should clear future history and overwrite when called with no args', ->
      x = new Outlet 42
      out = new Outlet foo = sinon.spy -> x.get()
      expect(foo).calledOnce
      @a.to.get(['controller','delegate']).set(out)
      @a.navigate()
      expect(@a.to.controller.delegate.get()).eq 42
      x.set(43)
      expect(foo).calledTwice
      expect(@a.to.controller.delegate.get()).eq 43
      @a.navigate(0)
      expect(out.get()).eq 42
      expect(@a.to.controller.delegate.get()).eq 42
      @a.navigate()
      expect(@a.to.index).eq 1
      expect(@a.length).eq 2
      expect(out.get()).eq 42
      expect(@a.to.controller.delegate.get()).eq 42
      @a.navigate(0)
      expect(out.get()).eq 42
      expect(@a.to.controller.delegate.get()).eq 42
      @a.navigate(1)
      expect(out.get()).eq 42
      expect(@a.to.controller.delegate.get()).eq 42


  describe '#noInherit', ->
    beforeEach ->
      @a = new HistoryOutlets

    it 'when nested, should cause future values to see undefined, but past values remain the same', ->
      @a.to.get(['controller','delegate']).set(42)
      @a.navigate()
      @a.to.noInherit(['controller','delegate'])
      expect(@a.to.controller.delegate).not.exist
      expect(@a.to.get(['controller','delegate']).get()).not.exist
      expect(@a.from.get(['controller','delegate']).get()).eq 42

  describe 'from outlets', ->
    beforeEach ->
      @a = new HistoryOutlets
    it 'should set the right index for to and from when navigating', ->
      expect(@a.from.index).eq -1
      expect(@a.to.index).eq 0
      @a.navigate()
      expect(@a.from.index).eq 0
      expect(@a.to.index).eq 1

  describe 'web use case', ->
    beforeEach ->
      @a = new HistoryOutlets

    # this should have been a cucumber feature, not an rspec/mocha test...
    it 'should allow outlet initialization without re-drawing the dom and have expected values when navigating', ->
      foo = "foo"
      bar = 'bar'
      baz = 'baz'

      # server script does some restoration
      # @a.to.get(['controller','#view']).set(foo)
      @a.to.get(['controller','view','firstName']).set(foo)

      setsDom = sinon.spy ->

      buildView = =>
        instOutlet = @a.to.get(['controller','#view'])
        return instOutlet.get() if instOutlet.get()?

        view = {
          outlets: ['firstName'],
          outletMethods: [
            (firstName) -> setsDom()
          ]
        }

        # configure outlets. if one already exists, don't want to update the
        # dom because it means the dom already has this value

        [outlets, view.outlets] = [view.outlets, []]
        for name in outlets
          hd = @a.to.get(['controller','view',name])
          outlet = new Outlet(hd.get())
          hd.set(outlet)
          view.outlets[name] = outlet

        [outletMethods, view.outletMethods] = [view.outletMethods, []]
        for func in outletMethods
          view.outletMethods.push new OutletMethod func, view.outlets, silent: true

        instOutlet.set view

      # view instance outlets in the controller
      viewFrom = new Outlet
      viewTo = new Outlet

      # from model
      firstNameTo = new Outlet foo
      @a.to.get(['controller','firstNameTo']).set(firstNameTo)

      bindControllerViewOutlets = =>
        viewTo.set buildView()
        @a.to.get(['controller','#view']).set(viewTo)
        viewTo.get().outlets.firstName.set(firstNameTo)

      unbindControllerView = =>
        viewTo.get().outlets.firstName.unset(firstNameTo)
        @a.to.noInherit(['controller','#view'])
        @a.to.noInherit(['controller','view'])

      bindControllerViewOutlets()
      @a.from.get(['controller','#view']).sets(viewFrom)
      expect(setsDom).not.called
      expect(viewTo.get().outlets.firstName.get()).eq foo

      # now navigate and change settings
      @a.navigate()
      firstNameTo.set(bar)
      expect(viewTo.get().outlets.firstName.get()).eq bar
      expect(setsDom).calledOnce

      # now navigate and ensure dom is updated
      @a.navigate(0)
      expect(firstNameTo.get()).eq foo
      expect(viewTo.get().outlets.firstName.get()).eq foo
      expect(setsDom).calledTwice

      # now navigate re-creating the view so there are separate from and to views
      @a.navigate()
      expect(firstNameTo.get()).eq foo
      unbindControllerView()
      expect(setsDom).calledTwice
      firstNameTo.set(bar)
      expect(setsDom).calledTwice # because no dom is bound to firstNameTo
      bindControllerViewOutlets()
      expect(setsDom).calledThrice # new call because built a new view with a new dom
      expect(viewFrom.get()).exist
      expect(viewTo.get()).not.eq viewFrom.get()
      expect(viewFrom.get().outlets.firstName.get()).eq foo
      expect(viewTo.get().outlets.firstName.get()).eq bar

      # should be able to determine direction of navigation
      expect(@a.from.index).eq 0
      expect(@a.to.index).eq 1

      # should silently not update when underlying data is changed
      expect(viewFrom.get().outlets.firstName.get()).eq foo
      viewFrom.get().outlets.firstName.set("invalid set")
      oldFrom = viewFrom.get()
      Cascade.Block =>
        @a.navigate(0)
        expect(@a.to.index).eq 0
        expect(@a.from.index).eq 1
        # have to unbind & rebind since navigation event changed view params
        unbindControllerView()
        bindControllerViewOutlets()
      expect(viewTo.get()).eq oldFrom
      expect(viewTo.get().outlets.firstName.get()).eq foo
      expect(viewFrom.get().outlets.firstName.get()).eq bar

  ###
  describe 'events', ->
    it 'should emit a newOutlet event after new outlets are created', ->
      @a = new HistoryOutlets
      @a.on 'newOutlet', fn = sinon.spy ->
      @a.to.get(['foo','bar']).set(42)
      expect(fn).calledOnce

    it 'should send 3 params: path, key and the outlet', ->
      @a = new HistoryOutlets
      args = []
      @a.on 'newOutlet', fn = sinon.spy -> args = [].splice.call(arguments,0)
      @a.to.get(['foo','bar']).set(42)
      expect(args.length).eq 3
      expect(Array.isArray(args[0])).true
      expect(args[0][0]).eq 'foo'
      expect(args[0].length).eq 1
      expect(args[1]).eq 'bar'
      expect(args[2].get()).eq 42
  ###

  describe 'swapping outlets with pending calculations', ->
    describe 'when there are pending outflows after a navigation', ->
      it 'should not calculate the outflows for outlets that are replaced because of a previous outflow', ->
        ho = new HistoryOutlets
        o1 = ho.get(['ace','tlcType'])
        o1.set("list type")

        o1_5 = ho.get(['ace','tlc'])
        o1_5.set("list")

        o2 = ho.get(['ace','Controller','foo'])
        o2.set("some controller property")

        o3 = new Outlet o2

        o1.outflows.add =>
          unless 0 == o1.get().indexOf(o1_5.get())
            ho.noInherit(['ace','Controller'])
            o1_5.set(o1.get()[0...-5])

        Cascade.Block =>
          # called by a controller somewhere
          ho.navigate()
          ho.get(['ace','tlcType']).set('reader type')
          ho.get(['ace','Controller','foo']).set('new property')

        expect(o3.get()).eq "some controller property"
        expect(ho.get(['ace','Controller','foo']).get()).eq 'new property'
        expect(ho.get(['ace','tlcType']) == o1).true

        ho.navigate(0)

        expect(o3.get()).eq "some controller property"
        expect(ho.get(['ace','Controller','foo']).get()).eq 'some controller property'


