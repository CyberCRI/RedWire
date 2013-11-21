#!/usr/bin/env coffee

# IMPORTS 
escodegen = require("escodegen")
esprima = require("esprima")
fs = require("fs.extra")
mime = require("mime")
path = require("path")
util = require("util")


# CONSTANTS
OUTPUT_VERSION = 0.1

# 2-space indent 
CODE_GENERATION_OPTIONS =
  indent: "  "


# FUNCTIONS
toJson = (obj) -> JSON.stringify(obj, null, 2)

parsedToObj = (parsed) -> 
  switch parsed.type
    when "Literal"
      return parsed.value
    when "ObjectExpression"
      obj = {}
      for property in parsed.properties
        propertyName = property.key.name || property.key.value
        obj[propertyName] = parsedToObj(property.value)
      return obj
    when "FunctionExpression" 
      # Don't include the upper-level BlockStatement
      return (escodegen.generate(body, CODE_GENERATION_OPTIONS) for body in parsed.body.body).join("\n")
    else
      util.error("How do I handle parsed type #{parsed.type}?")
      process.exit(2)

createDataUri = (filename) ->
  buffer = fs.readFileSync(filename)
  mimeType = mime.lookup(filename)
  return "data:#{mimeType};#{buffer.toString('base64')}"


# MAIN
if process.argv.length < 4
  util.error("Usage: coffee convert_from_directory.coffee <input_dir> <output_file>")
  process.exit(1)

inputDir = process.argv[2]
outputDir = process.argv[3]

# This object will be written out as JSON at the end 
outputObj = 
  version: OUTPUT_VERSION
  model: {}
  layout: {}
  actions: {}
  tools: {}
  assets: {}

# Actions are a JS file that needs to be parsed
parsedActions = esprima.parse(fs.readFileSync(path.join(inputDir, "actions.js"), { encoding: "utf8" }))
# TODO: remove references to "this"
outputObj.actions = parsedToObj(parsedActions.body[0].expression)

# Copy over layout JSON
outputObj.layout = JSON.parse(fs.readFileSync(path.join(inputDir, "layout.json"), { encoding: "utf8" }))

# Copy over model JSON
outputObj.model = JSON.parse(fs.readFileSync(path.join(inputDir, "model.json"), { encoding: "utf8" }))

# TODO: Copy over tools

# Create data-URI encoded versions of all assets
assetMap = JSON.parse(fs.readFileSync(path.join(inputDir, "assets.json"), { encoding: "utf8" }))
for name, filename of outputObj.assets
  outputObj.assets[name] = createDataUri(filename)

fs.writeFileSync(path.join(outputDir, "game.json"), toJson(outputObj))
