#!/usr/bin/env coffee

# IMPORTS 
util = require('util')
graphviz = require('graphviz')
fs = require("fs.extra")
path = require("path")

# CONSTANTS
USAGE = """
  Usage: coffee draw_graphs.coffee <layout_filer> <output_file>
    
    output_file must be a PNG
"""

# FUNCTIONS

# Returns graphviz nodes
toJson = (obj) -> JSON.stringify(obj, null, 2)

keys = (obj) -> key for key, value of obj

processLayout = (graph, brick, path = []) ->
  if "send" of brick
    keyNames = keys(brick.send).join('\n')
    name = "SEND\n#{keyNames}"
    style = {}
  else if "action" of brick
    name = "ACTION\n#{brick.action}"
    style =
      shape: "box"
  else if "foreach" of brick
    name = "FOREACH\n#{brick.foreach.from}"
    style = 
      shape: "diamond"
  else 
    throw new Error("Unknown node type for '#{toJson(node)}'")

  node = graph.addNode("#{path.join('.')}: #{name}", style)

  if brick.children
    for index, childBrick of brick.children
      childNode = processLayout(graph, childBrick, path.concat(index))
      edge = g.addEdge(node, childNode)
      if "name" of childBrick then edge.set("label", childBrick.name) 
  return node


# MAIN
if process.argv.length < 4
  util.error(USAGE)
  process.exit(1)

inputFile = process.argv[2]
outputFile = process.argv[3]

g = graphviz.digraph("G");

layout = JSON.parse(fs.readFileSync(inputFile, { encoding: "utf8" }))
processLayout(g, layout)

g.output("png", outputFile)
