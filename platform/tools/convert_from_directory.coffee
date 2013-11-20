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
fs.extra.mkdirRecursiveSync(outputDir)

# This object will be written out as JSON at the end 
outputObj = 
  version: OUTPUT_VERSION

# Copy over asset JSON
outputObj.assets = JSON.parse(fs.readFileSync(path.join(inputDir, "/assets.json"), { encoding: "utf8" }))

# TODO: remove relative directories before assets

# Copy referenced assets
for name, filename of outputObj.assets
  fs.copy filename, path.join(outputDir, filename), (err) -> 
    if err? 
      util.error("cannot copy #{filename}")
      exit(2)

fs.writeFileSync(path.join(outputDir, "/game.json"), JSON.stringify(outputObj))




