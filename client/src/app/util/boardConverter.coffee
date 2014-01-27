String::capitalize = ->
  @replace /(^|\s)([a-z])/g, (m, p1, p2) ->
    p1 + p2.toUpperCase()

generateText = (source) ->
  process = source.process
  if process
    _.string.humanize(process).capitalize()
  else
    'Effector'

generateType = (source) ->
  if source.process
    'switch'
  else
    'action'

pathToString = (path) -> "[#{path.join(",")}]" 

makeChipButtons = (path) -> """
  <a href="" class="btn btn-small" editChip="#{pathToString(path)}"><i class="icon-edit"></i></a>
  <a href="" class="btn btn-small" removeChip="#{pathToString(path)}"><i class="icon-trash"></i></a>
  """

angular.module('gamEvolve.util.boardConverter', [])

.factory 'boardConverter', ->
    convert: (source, path = []) ->
      converted =
        'text': generateText(source) + makeChipButtons(path)
        'type': generateType(source)
        'state':
          'opened': path.length is 0 # Only the root node is opened by default
        'source': JSON.parse(JSON.stringify(source));
      delete converted.source.children
      converted.children = []
      if source.children?
        for childIndex, child of source.children
          converted.children.push(@convert(child, GE.appendToArray(path, childIndex)))
      converted