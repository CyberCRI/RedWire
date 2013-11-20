#!/usr/bin/env coffee

OUTPUT_VERSION = 0.1

escodegen = require("escodegen")
esprima = require("esprima")
fs = require("fs.extra")
path = require("path")
util = require("util")


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
# TODO: literals such as objects or strings should be returned as such, without string quoiting
# TODO: functions should be returned without the braces
# TODO: quoted action names such as "if" are returned as undefined
parsedActions = esprima.parse(fs.readFileSync(path.join(inputDir, "/actions.js"), { encoding: "utf8" }))
for action in parsedActions.body[0].expression.properties
  actionName = action.key.name
  outputObj.actions[actionName] = {}
  for property in action.value.properties
    propertyName = property.key.name || propery.key.value
    switch property.value.type
      when "ObjectExpression", "Literal"
        outputObj.actions[actionName][propertyName] = escodegen.generate(property.value)
      when "FunctionExpression" 
        outputObj.actions[actionName][propertyName] = escodegen.generate(property.value.body)
      else
        util.error("Action #{actionName} has unrecognized type #{property.value.type}")
        process.exit(2)

# Copy over layout JSON
outputObj.layout = JSON.parse(fs.readFileSync(path.join(inputDir, "/layout.json"), { encoding: "utf8" }))

# Copy over model JSON
outputObj.model = JSON.parse(fs.readFileSync(path.join(inputDir, "/model.json"), { encoding: "utf8" }))

# Copy over asset JSON
outputObj.assets = JSON.parse(fs.readFileSync(path.join(inputDir, "/assets.json"), { encoding: "utf8" }))

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


# TODO: pretty-print JSON output
fs.writeFileSync(path.join(outputDir, "/game.json"), JSON.stringify(outputObj))
