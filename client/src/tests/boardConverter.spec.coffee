describe 'Board Converter', ->

  sut = undefined
  board = referenceBoards

  beforeEach ->
    module 'gamEvolve.util.boardConverter'
    inject (boardConverter) -> sut = boardConverter

  it 'should convert root chip', ->
    input = board.EMPTY_DO_IN_PARALLEL.source
    output = sut.convert(input)
    expect(output.attr.rel).toEqual 'switch'

  it 'should handle multiple chip process types', ->
    input = board.EMPTY_DO_IN_SEQUENCE.source
    output = sut.convert(input)
    expect(output.attr.rel).toEqual 'switch'

  it 'should make root switch open by default', ->
    input = board.EMPTY_DO_IN_PARALLEL.source
    output = sut.convert(input)
    expect(output.state).toBe 'open'

  it 'should convert single child in switch', ->
    input = board.SINGLE_CHILD.source
    output = sut.convert(input)
    expect(output.children.length).toBe 1
    expect(output.metadata.source.children).toBe undefined
    expect(output.children[0].data).toEqual sut.convert(input.children[0], [0]).data

  it 'should convert multiple children in switch', ->
    input = board.MULTIPLE_CHILDREN.source
    output = sut.convert(input)
    expect(output.children.length).toBe 2

  it 'should convert deep tree', ->
    input = board.DEEP.source
    output = sut.convert(input)
    expect(output.children[0].children.length).toBe 2