String::capitalize = ->
  @replace /(^|\s)([a-z])/g, (m, p1, p2) ->
    p1 + p2.toUpperCase()

generateText = (source) ->
  if "switch" of source then "Switch - " + source.process
  else if "processor" of source then "Processor - " + source.processor
  else if "emitter" of source then "Emitter"
  else if "splitter" of source then "Splitter"
  else throw new Error("Cannot find type of chip #{source}")

# TODO: expand this list
generateType = (source) ->
  if source.switch
    'switch'
  else
    'processor'

pathToString = (path) -> "[#{path.join(",")}]" 

makeChipButtons = (path) -> """
  <a href="" class="btn btn-small" editChip="#{pathToString(path)}"><i class="icon-edit"></i></a>
  <a href="" class="btn btn-small" removeChip="#{pathToString(path)}"><i class="icon-trash"></i></a>
  """

  
angular.module('gamEvolve.util.boardConverter', [])

.factory 'boardConverter', ->
    
    convert: (source, path = []) ->
      state = 'closed'
      if path.length is 0 
        state = 'open' # Only the root node is opened by default
      converted =
        data: generateText(source) + makeChipButtons(path)
        attr:
          rel: generateType(source)
        state: state
        metadata:
          source: JSON.parse(JSON.stringify(source)) # Copy source
          path: path
      delete converted.metadata.source.children
      converted.children = []
      if source.children?
        for childIndex, child of source.children
          converted.children.push(@convert(child, GE.appendToArray(path, childIndex)))
      converted