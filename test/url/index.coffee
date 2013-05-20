Url = lib 'index'
querystring = lib 'querystring'

describe 'Url', ->
  it 'should have reasonable defaults given empty path', ->
    url = new Url
    expect(url.query).deep.eq {}
    expect(url.search).eq ''
    expect(url.protocol).not.exist
    expect(url.host).not.exist
    expect(url.hostname).not.exist
    expect(url.href).eq ''
    expect(url.path).eq ''
    expect(url.pathname).eq ''

  it 'should parse full URL with host and path', ->
    url = 'http://www.example.com/path/to/file.html'
    result = new Url(url)
    expect(result.href).eq url
    expect(result.path).eq result.pathname
    expect(result.search).eq ''
    expect(result.query).deep.eq {}
    expect(result.host).eq result.hostname
    expect(result.port).not.exist

  it 'should parse paths', ->
    url = '/path/to/file.html'
    result = new Url(url)
    expect(result.href).eq url
    expect(result.host).not.exist
    expect(result.hostname).not.exist
    expect(result.path).eq url
    expect(result.path).eq result.pathname

  it 'should parse //...', ->
    url = '//foo.com/path/to/file.html'
    result = new Url(url)
    expect(result.protocol).not.exist
    expect(result.href).eq url
    expect(result.host).eq result.hostname
    expect(result.host).eq 'foo.com'
    expect(result.path).eq result.pathname
    expect(result.path).eq '/path/to/file.html'

  it 'should parse //... as a path if slashes is set to false', ->
    url = '//foo.com/path/to/file.html'
    newUrl = '/foo.com/path/to/file.html'
    result = new Url(url, slashes: false)
    expect(result.href).eq newUrl
    expect(result.host).not.exist
    expect(result.hostname).not.exist
    expect(result.path).eq newUrl
    expect(result.pathname).eq result.path

  it 'should parse auth', ->
    url = '//user:pass@foo.com/path/to/file.html'
    result = new Url(url)
    expect(result.auth).eq 'user:pass'
    expect(result.protocol).not.exist
    expect(result.href).eq url
    expect(result.host).eq result.hostname
    expect(result.host).eq 'foo.com'
    expect(result.path).eq result.pathname
    expect(result.path).eq '/path/to/file.html'

  it 'should parse the query string', ->
    url = '/foo/bar?one=two&three=four'
    result = new Url(url)
    expect(result.href).eq url
    expect(result.host).not.exist
    expect(result.hostname).not.exist
    expect(result.pathname).eq '/foo/bar'
    expect(result.path).eq url
    expect(result.search).eq '?one=two&three=four'
    expect(result.query).deep.eq querystring.parse result.search[1..]

  it 'should parse the hash', ->
    url = '/foo/bar#a/hash'
    result = new Url(url)
    expect(result.href).eq url
    expect(result.host).not.exist
    expect(result.hostname).not.exist
    expect(result.pathname).eq '/foo/bar'
    expect(result.path).eq result.pathname
    expect(result.search).eq ''
    expect(result.query).deep.eq {}
    expect(result.hash).eq '#a/hash'

  it 'should parse all the pieces together', ->
    url = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
    result = new Url(url)
    expect(result.href).eq url
    expect(result.protocol).eq 'https:'
    expect(result.auth).eq 'user:pass'
    expect(result.hostname).eq 'foo.com'
    expect(result.port).eq 80
    expect(result.host).eq 'foo.com:80'
    expect(result.pathname).eq '/path/to/file.html'
    expect(result.path).eq '/path/to/file.html?var=val'
    expect(result.search).eq '?var=val'
    expect(result.query).deep.eq {var: 'val'}
    expect(result.hash).eq '#a/hash'

  it 'should escape special characters (but not HTML encode) the URL', ->
    url = 'https://user:pass@foo.com:80/path/to/the file\'s html?var=val one+two#a super%20<hash>%'
    result = new Url(url)
    expect(result.href).eq 'https://user:pass@foo.com:80/path/to/the%20file%27s%20html?var=val%20one+two#a%20super%20%3Chash%3E%'

  it 'should consolidate duplicate slashes in path', ->
    url = '/foo//bar'
    result = new Url(url)
    expect(result.href).eq '/foo/bar'
    expect(result.host).not.exist
    expect(result.hostname).not.exist
    expect(result.pathname).eq '/foo/bar'
    expect(result.path).eq result.pathname
    expect(result.search).eq ''
    expect(result.query).deep.eq {}

  describe '#defaults', ->
    it 'should set host, protocol, etc.', ->
      rhs = new Url 'http://www.example.com/bar?boo=mo#bazoo'
      lhs = new Url '/foo/bar#baz', rhs
      expect(lhs.href).eq 'http://www.example.com/foo/bar#baz'

  describe '#reform', ->
    it 'should reform the full url', ->
      result = new Url
      url = 'http://www.example.com/path/to/file.html'
      result.reform href:url
      expect(result.href).eq url
      expect(result.path).eq result.pathname
      expect(result.search).eq ''
      expect(result.query).deep.eq {}
      expect(result.host).eq result.hostname
      expect(result.port).not.exist

    it 'should add port', ->
      url = 'https://user:pass@foo.com/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      result = new Url url
      result.reform port: 80
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'foo.com'
      expect(result.port).eq 80
      expect(result.host).eq 'foo.com:80'
      expect(result.pathname).eq '/path/to/file.html'
      expect(result.path).eq '/path/to/file.html?var=val'
      expect(result.search).eq '?var=val'
      expect(result.query).deep.eq {var: 'val'}
      expect(result.hash).eq '#a/hash'

    it 'should set hostname', ->
      url = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@bar.com:80/path/to/file.html?var=val#a/hash'
      result = new Url url
      result.reform hostname: 'bar.com'
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'bar.com'
      expect(result.port).eq 80
      expect(result.host).eq 'bar.com:80'
      expect(result.pathname).eq '/path/to/file.html'
      expect(result.path).eq '/path/to/file.html?var=val'
      expect(result.search).eq '?var=val'
      expect(result.query).deep.eq {var: 'val'}
      expect(result.hash).eq '#a/hash'

    it 'should set host', ->
      url = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@bar.com:8080/path/to/file.html?var=val#a/hash'
      result = new Url url
      result.reform host: 'bar.com:8080'
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'bar.com'
      expect(result.port).eq 8080
      expect(result.host).eq 'bar.com:8080'
      expect(result.pathname).eq '/path/to/file.html'
      expect(result.path).eq '/path/to/file.html?var=val'
      expect(result.search).eq '?var=val'
      expect(result.query).deep.eq {var: 'val'}
      expect(result.hash).eq '#a/hash'

    it 'should set pathname', ->
      url = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@foo.com:80/another/path?var=val#a/hash'
      result = new Url url
      result.reform pathname: '/another/path'
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'foo.com'
      expect(result.port).eq 80
      expect(result.host).eq 'foo.com:80'
      expect(result.pathname).eq '/another/path'
      expect(result.path).eq '/another/path?var=val'
      expect(result.search).eq '?var=val'
      expect(result.query).deep.eq {var: 'val'}
      expect(result.hash).eq '#a/hash'

    it 'should set query', ->
      url = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@foo.com:80/path/to/file.html?var2=val2#a/hash'
      result = new Url url
      result.reform query: {var2: 'val2'}
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'foo.com'
      expect(result.port).eq 80
      expect(result.host).eq 'foo.com:80'
      expect(result.pathname).eq '/path/to/file.html'
      expect(result.path).eq '/path/to/file.html?var2=val2'
      expect(result.search).eq '?var2=val2'
      expect(result.query).deep.eq {var2: 'val2'}
      expect(result.hash).eq '#a/hash'

    it 'should set search', ->
      url = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@foo.com:80/path/to/file.html?var2=val2#a/hash'
      result = new Url url
      result.reform search: '?var2=val2'
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'foo.com'
      expect(result.port).eq 80
      expect(result.host).eq 'foo.com:80'
      expect(result.pathname).eq '/path/to/file.html'
      expect(result.path).eq '/path/to/file.html?var2=val2'
      expect(result.search).eq '?var2=val2'
      expect(result.query).deep.eq {var2: 'val2'}
      expect(result.hash).eq '#a/hash'

    it 'should set path', ->
      url = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@foo.com:80/another/path?var2=val2#a/hash'
      result = new Url url
      result.reform path: '/another/path?var2=val2'
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'foo.com'
      expect(result.port).eq 80
      expect(result.host).eq 'foo.com:80'
      expect(result.pathname).eq '/another/path'
      expect(result.path).eq '/another/path?var2=val2'
      expect(result.search).eq '?var2=val2'
      expect(result.query).deep.eq {var2: 'val2'}
      expect(result.hash).eq '#a/hash'

    it 'should set auth', ->
      url = 'https://foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://user:pass@foo.com:80/path/to/file.html?var=val#a/hash'
      result = new Url url
      result.reform auth: 'user:pass'
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.auth).eq 'user:pass'
      expect(result.hostname).eq 'foo.com'
      expect(result.port).eq 80
      expect(result.host).eq 'foo.com:80'
      expect(result.pathname).eq '/path/to/file.html'
      expect(result.path).eq '/path/to/file.html?var=val'
      expect(result.search).eq '?var=val'
      expect(result.query).deep.eq {var: 'val'}
      expect(result.hash).eq '#a/hash'

    it 'should set hash', ->
      url = 'https://foo.com:80/path/to/file.html?var=val#a/hash'
      url2 = 'https://foo.com:80/path/to/file.html?var=val#foo%20bar'
      result = new Url url
      result.reform hash: '#foo bar'
      expect(result.href).eq url2
      expect(result.protocol).eq 'https:'
      expect(result.hostname).eq 'foo.com'
      expect(result.port).eq 80
      expect(result.host).eq 'foo.com:80'
      expect(result.pathname).eq '/path/to/file.html'
      expect(result.path).eq '/path/to/file.html?var=val'
      expect(result.search).eq '?var=val'
      expect(result.query).deep.eq {var: 'val'}
      expect(result.hash).eq '#foo%20bar'
