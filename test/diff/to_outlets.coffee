patchOutlets = lib 'to_outlets'
Outlet = lib '../cascade/outlet'
diff = lib 'index'
clone = lib '../clone'

describe.only 'patch_outlets', ->
  it 'should set outlets when originally empty', ->
    a = {}
    b = {a: [1,2,3]}
    o1 = new Outlet
    o2 = new Outlet
    o3 = new Outlet
    outlets = { 'a': { '_': o1, 2: { '_': o2}, 3: { '_': o3}}}

    d = diff(a,b)

    patchOutlets(outlets, d, b)
    expect(o1.get()).deep.eq [1,2,3]
    expect(o2.get()).eq 3
    expect(o3.get()).not.exist

  it 'should set outlets that refer to array indices when pushed', ->
    a = {a: [1,2,3]}
    b = {a: [1,2,3,4,5,6]}
    o1 = new Outlet clone(a.a)
    o2 = new Outlet clone(a.a[2])
    o3 = new Outlet clone(a.a[3])
    o4 = new Outlet clone(a.a[5])
    d = [{'o':0, 'k':'a', 'd': [{'o':1,'i':-1,'v':4},{'o':1,'i':-1,'v':5},{'o':1,'i':-1,'v':6}]}]
    ac = clone(a)
    expect(diff.patch(ac, d)).deep.eq b

    outlets = { 'a': { '_': o1, 2: { '_': o2}, 3: { '_': o3}, 5: {'_':o4}}}

    patchOutlets(outlets, d, b)
    expect(o1.get()).deep.eq [1,2,3,4,5,6]
    expect(o2.get()).eq 3
    expect(o3.get()).eq 4
    expect(o4.get()).eq 6

  it 'should set outlets that refer to array indices when popped', ->
    a = {a: [1,2,3]}
    b = {a: [1,2]}
    o1 = new Outlet clone(a.a)
    o2 = new Outlet clone(a.a[1])
    o3 = new Outlet clone(a.a[3])
    o4 = new Outlet clone(a.a[5])
    d = [{'o':0, 'k':'a', 'd': [{'o':-1,'i':-1}]}]
    ac = clone(a)
    expect(diff.patch(ac, d)).deep.eq b

    outlets = { 'a': { '_': o1, 1: { '_': o2}, 3: { '_': o3}, 5: {'_':o4}}}

    patchOutlets(outlets, d, b)
    expect(o1.get()).deep.eq [1,2]
    expect(o2.get()).eq 2
    expect(o3.get()).not.exist
    expect(o4.get()).not.exist

  it 'should work with complex keys', ->
    a = {a: b: [1,2,3]}
    b = {a: b: [1,2]}
    o1 = new Outlet clone(a.a.b)
    o2 = new Outlet clone(a.a.b[1])
    o3 = new Outlet clone(a.a.b[2])
    o4 = new Outlet clone(a.a.b[5])
    d = [{'o':0, 'k':'a.b', 'd': [{'o':-1,'i':-1}]}]
    ac = clone(a)
    expect(diff.patch(ac, d)).deep.eq b

    outlets = { 'a': { 'b': { '_': o1, 1: { '_': o2}, 2: { '_': o3}, 5: {'_':o4}}}}

    patchOutlets(outlets, d, b)
    expect(o1.get()).deep.eq [1,2]
    expect(o2.get()).eq 2
    expect(o3.get()).not.exist
    expect(o4.get()).not.exist

