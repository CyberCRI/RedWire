#!/usr/bin/env coffee

# IMPORTS 
_ = require("underscore")
fs = require("fs.extra")
path = require("path")
util = require("util")


# CONSTANTS
OUTPUT_VERSION = 0.2


# FUNCTIONS
toJson = (obj) -> JSON.stringify(obj, null, 2)


# MAIN
if process.argv.length < 3
  util.error("Usage: coffee convert_to_v2.coffee <input_files>, <input_file>, ...")
  process.exit(1)

for inputFileName in process.argv[2..]
  # This object will be written out as JSON at the end 
  inputGame = JSON.parse(fs.readFileSync(inputFileName, { encoding: "utf8"}))

  if inputGame.fileVersion >= OUTPUT_VERSION
    console.warn("Skipping #{inputFileName} which is already at version #{inputGame.fileVersion}")
    continue

  outputGame = 
    name: inputGame.name
    fileVersion: OUTPUT_VERSION
    processors: inputGame.processors
    switches: inputGame.switches
    transformers: inputGame.transformers
    circuits: 
      main:
        memory: inputGame.memory
        board: inputGame.board
        assets: inputGame.assets
        io: inputGame.io

  outputFileName = path.join(path.dirname(inputFileName), path.basename("#{path.basename(inputFileName, ".json")}_v2.json"))
  console.log("Creating #{outputFileName}")
  fs.writeFileSync(outputFileName, toJson(outputGame))
