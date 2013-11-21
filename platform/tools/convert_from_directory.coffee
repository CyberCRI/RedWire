#!/usr/bin/env coffee

# IMPORTS 
escodegen = require("escodegen")
esprima = require("esprima")
fs = require("fs.extra")
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


# MAIN
if process.argv.length < 4
  util.error("Usage: coffee convert_from_directory.coffee <input_dir> <output_dir>")
  process.exit(1)

inputDir = process.argv[2]
outputDir = process.argv[3]

# TODO: remove output directory before starting?
fs.mkdirRecursiveSync(outputDir)

# This object will be written out as JSON at the end 
outputObj = 
  actions: {}
  assets: {}
  layout: {}
  model: {}
  version: OUTPUT_VERSION

# Actions are a JS file that needs to be parsed
parsedActions = esprima.parse(fs.readFileSync(path.join(inputDir, "actions.js"), { encoding: "utf8" }))
outputObj.actions = parsedToObj(parsedActions.body[0].expression)

# Copy over layout JSON
outputObj.layout = JSON.parse(fs.readFileSync(path.join(inputDir, "layout.json"), { encoding: "utf8" }))

# Copy over model JSON
outputObj.model = JSON.parse(fs.readFileSync(path.join(inputDir, "model.json"), { encoding: "utf8" }))

# Copy over asset JSON
outputObj.assets = JSON.parse(fs.readFileSync(path.join(inputDir, "assets.json"), { encoding: "utf8" }))

# TODO: create base64 version of all assets

# Copy referenced assets
for name, filepath of outputObj.assets
  # Remove extra directories for output destination
  filename = path.basename(filepath)
  outputObj.assets[name] = filename
  do (filepath, filename) ->
    fs.copy path.join(inputDir, filepath), path.join(outputDir, filename), (err) -> 
      if err? 
        util.error("WARNING: Cannot copy #{filename}: #{err}")

fs.writeFileSync(path.join(outputDir, "game.json"), toJson(outputObj))
