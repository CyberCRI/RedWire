String::capitalize = ->
  @replace /(^|\s)([a-z])/g, (m, p1, p2) ->
    p1 + p2.toUpperCase()

generateHeading = (source) -> if source.name? then "<b>#{JSON.stringify(source.name)}:</b>" else ""

generateTitle = (source) -> source.comment || 'Untitled'

generateComment = (source) ->
  switch generateType(source)
    when "switch" then "Switch #{source.switch}"
    when "processor" then "Processor #{source.processor}"
    when "emitter" then "Emitter"
    when "splitter" then "Splitter"
    else throw new Error("Unknown type of chip #{source}")

generateText = (source) -> "#{generateHeading(source)} #{generateTitle(source)} (#{generateComment(source)})"

# TODO: expand this list
generateType = (source) ->
  if "switch" of source then "switch"
  else if "processor" of source then "processor"
  else if "emitter" of source then "emitter"
  else if "splitter" of source then "splitter"
  else throw new Error("Cannot find type of chip #{source}")

makeChipButtons = (nodeId, parentNodeId, muted) -> """
  <a href="" class="btn btn-small" editChip nodeId="#{nodeId}"><i class="icon-edit"></i></a>
  <a href="" class="btn btn-small" muteChip nodeId="#{nodeId}" parentNodeId="#{parentNodeId}">#{if muted then "MUTED" else "Mute"}</a>
  <a href="" class="btn btn-small" removeChip nodeId="#{nodeId}" parentNodeId="#{parentNodeId}"><i class="icon-trash"></i></a>
  """


angular.module('gamEvolve.util.boardConverter', ['gamEvolve.game.boardTree'])

.factory 'boardConverter', (nodes) ->

    convert: (treeRoot) ->
      @convertNode treeRoot, -1

    convertNode: (node, parentNodeId) ->
      if parentNodeId < 0
        nodeId = nodes.registerRoot node
      else
        nodeId = nodes.register node
      converted =
        data: generateText(node) + makeChipButtons(nodeId, parentNodeId, node.muted)
        attr:
          rel: generateType(node)
        state: nodes.findState(nodeId)
        metadata:
          source: JSON.parse(JSON.stringify(node)) # Copy source
          nodeId: nodeId
      delete converted.metadata.source.children
      if node.children?
        converted.children = []
        for child in node.children
          converted.children.push(@convertNode(child, nodeId))
      converted

    revert: (treeJson) ->
      @revertNode(treeJson)

    revertNode: (nodeJson) ->
      node = nodeJson.metadata.source
      if nodeJson.children?
        node.children = []
        for childJson in nodeJson.children
          child = @revertNode(childJson)
          node.children.push child
      node