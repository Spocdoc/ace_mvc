tomongo = lib 'to_mongo'
mongodb = require 'mongodb',1
diff = lib 'index'

describe 'to_mongo', ->
  before (done) ->
    @timeout(5000)
    @server = new mongodb.Server '/tmp/mongodb-27017.sock'
    @db = new mongodb.Db 'ace_mocha', @server,
      'w': 1
      'native_parser': true
      'logger': console

    @db.open (err, db) =>
      throw new Error(err) if err?
      db.dropDatabase (err, result) =>
        throw new Error(err) if err? or !result
        db.createCollection 'to_mongo', (err, coll) =>
          throw new Error(err) if err? or !coll
          @coll = coll
          done()

    @coll = "to_mongo"

  beforeEach (done) ->
    @coll.remove {}, (err) ->
      throw new Error(err) if err?
      done()

  it 'should replace strings', (done) ->
    a = {foo: 'bar'}
    b = {foo: 'bazoo'}
    d = diff(a,b)
    m = tomongo(d, b)
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should replace nested strings', (done) ->
    a = {foo: bar: 'bar'}
    b = {foo: bar: 'bazoo'}
    d = diff(a,b)
    m = tomongo(d, b)
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should replace nested numbers', (done) ->
    a = {foo: bar: 10}
    b = {foo: bar: 20}
    d = diff(a,b)
    m = tomongo(d, b)
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should increment nested numbers', (done) ->
    a = {'foo': 'bar': 10}
    b = {'foo': 'bar': 8}
    d = [{'o':0,'k':'foo','d':[{'o':0,'k':'bar','d':'d-2'}]}]
    expect(diff['patch']({'foo':'bar':10},d)).deep.eq b
    m = tomongo(d, b)
    expect(m['$inc']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should append to arrays', (done) ->
    a = {'foo': 'bar': [1,2,3]}
    b = {'foo': 'bar': [1,2,3,4]}
    d = [{'o':0,'k':'foo','d':[{'o':0,'k':'bar','d':['o':1,'i':-1,'v':4]}]}]
    expect(diff['patch']({'foo': 'bar': [1,2,3]},d)).deep.eq b
    m = tomongo(d, b)
    expect(m['$push']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should append to arrays with a single regular index insert at end', (done) ->
    a = {foo: bar: [1,2,3]}
    b = {foo: bar: [1,2,3,4]}
    d = diff(a,b)
    m = tomongo(d, b)
    expect(m['$push']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should append to arrays with a multiple regular index inserts at end', (done) ->
    a = {foo: bar: [1,2,3]}
    b = {foo: bar: [1,2,3,4,5,6]}
    d = diff(a,b)
    m = tomongo(d, b)
    expect(m['$push']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should pop arrays with a single regular index delete at end', (done) ->
    a = {foo: bar: [1,2,3,4]}
    b = {foo: bar: [1,2,3]}
    JSON.stringify(d = diff(a,b))
    m = tomongo(d, b)
    expect(m['$pop']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should not pop arrays with a multiple regular index deletes at end', (done) ->
    a = {foo: bar: [1,2,3,4,5,6]}
    b = {foo: bar: [1,2,3]}
    d = diff(a,b)
    m = tomongo(d, b)
    expect(m['$pop']).not.exist
    expect(m['$set']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should pop arrays with a single regular index delete at the beginning', (done) ->
    a = {foo: bar: [1,2,3]}
    b = {foo: bar: [2,3]}
    JSON.stringify(d = diff(a,b))
    m = tomongo(d, b)
    expect(m['$pop']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should not pop arrays with a multiple regular index deletes at the beginning', (done) ->
    a = {foo: bar: [1,2,3,4,5,6]}
    b = {foo: bar: [3,4,5,6]}
    d = diff(a,b)
    m = tomongo(d, b)
    expect(m['$pop']).not.exist
    expect(m['$set']).exist
    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id']
          expect(doc).deep.eq b
          done()

  it 'should work with partial diffs', (done) ->
    a = {_id: 'id', _v: 0, 'foo': { 'bar': [null, 'baz': {hello: 'world'}] } }
    c = {hello: 'mundo'}
    b = {_id: 'id', _v: 0, 'foo': { 'bar': [null, 'baz': {hello: 'mundo'}] } }
    path = ['foo','bar',1,'baz']
    d = diff(a, c, path: path)
    m = tomongo(d, b)

    @coll.insert a, =>
      @coll.update {}, m, =>
        @coll.findOne (err, doc) =>
          delete doc['_id'] unless b['_id']?
          expect(doc).deep.eq b
          done()

