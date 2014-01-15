processToText = (process) ->
  if process is 'doInParallel'
    'Do In Parallel'
  else if process is 'doInSequence'
    'Do In Sequence'
  else
    process

angular.module('gamEvolve.util.boardConverter', [])

.factory 'boardConverter', ->

    convert: (source, isRoot=true) ->
      converted =
        'text': processToText(source.process)
        'state':
          'opened': isRoot
        'source': JSON.parse(JSON.stringify(source));
      delete converted.source.children
      converted.children = []
      if source.children?
        for child in source.children
          converted.children.push(@convert(child, false))
      converted