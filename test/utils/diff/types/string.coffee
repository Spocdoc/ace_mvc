diff = lib '../index'

describe 'string diff', ->
  it 'should return a diff', ->
    a = 'foo'
    b = 'baroo'
    expect(diff(a,b)).exist

  it 'should restore the string', ->
    a = 'foo'
    b = 'baroob'
    d = diff(a,b)
    expect(diff['patch'](a,d)).eq b

  it 'should restore the string even when there are special characters', ->
    a = '+-&	|helloåem'
    b = '+-&	|helloaem'
    expect(diff['patch'](a,diff(a,b))).eq b
    expect(diff['patch'](b,diff(b,a))).eq a

  it 'should restore longer strings', ->
    a = """
    Diff takes two texts and finds the differences. This implementation works on a character by character basis. The result of any diff may contain 'chaff', irrelevant small commonalities which complicate the output. A post-diff cleanup algorithm factors out these trivial commonalities.
    """
    b = """
    Diff takes two texts and finds the diffreences. This works on a character by character basis. The result of any diff may contain 'chaff', redundant small commonalities which complicate the output. A post-diff cleanup algorithm factors out these trivial commonalities.
    """
    expect(diff['patch'](a,diff(a,b))).eq b
    expect(diff['patch'](b,diff(b,a))).eq a

