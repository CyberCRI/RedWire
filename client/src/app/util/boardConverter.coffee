String::capitalize = ->
  @replace /(^|\s)([a-z])/g, (m, p1, p2) ->
    p1 + p2.toUpperCase()

generateName = (source) -> source.comment || 'Untitled'

generateText = (source) -> 
  switch generateType(source)
    when "switch" then "#{generateName(source)} (#{source.switch})"
    when "processor" then "#{generateName(source)} (#{source.processor})"
    when "emitter" then "#{generateName(source)} (Emitter)"
    when "splitter" then "#{generateName(source)} (Splitter)"
    else throw new Error("Unknown type of chip #{source}")

# TODO: expand this list
generateType = (source) ->
  if "switch" of source then "switch"
  else if "processor" of source then "processor"
  else if "emitter" of source then "emitter"
  else if "splitter" of source then "splitter"
  else throw new Error("Cannot find type of chip #{source}")

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
      if source.children?
        converted.children = []
        for childIndex, child of source.children
          converted.children.push(@convert(child, GE.appendToArray(path, childIndex)))
      converted