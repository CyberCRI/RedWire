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

angular.module('gamEvolve.util.boardConverter', [])

.factory 'boardConverter', ->

    convert: (source, isRoot=true) ->
      converted =
        'text': generateText(source)
        'type': generateType(source)
        'state':
          'opened': isRoot
        'source': JSON.parse(JSON.stringify(source));
      delete converted.source.children
      converted.children = []
      if source.children?
        for child in source.children
          converted.children.push(@convert(child, false))
      converted