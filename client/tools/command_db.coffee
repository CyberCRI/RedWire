#!/usr/bin/env coffee


# IMPORTS 
program = require('commander')
_ = require("underscore")
fs = require("fs.extra")
path = require("path")
util = require("util")
request = require("request")


# CONFIGURATION

# Have request store and send cookies
request = request.defaults
  jar: true


# FUNCTIONS
statusIsError = (code) -> String(code)[0] == "4"

login = (baseUrl, user, password, cb) ->
  console.log("Logging into server #{baseUrl} with user #{user} and password #{password}")
  requestOptions = 
    url: "#{baseUrl}/users/login"
    json: 
      username: user
      password: password
  request.post requestOptions, (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Logged in")
    cb()

deleteAllThings = (baseUrl, thingType, cb) ->
  request "#{baseUrl}/#{thingType}", (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    things = JSON.parse(body)
    console.log("Deleting #{things.length} #{thingType}...")
    if things.length is 0 then cb()

    doneCount = 0
    for thing in things
      deleteThing baseUrl, thingType, thing.id, ->
        if ++doneCount == things.length then cb()

deleteThing = (baseUrl, thingType, id, cb) ->
  request.del "#{baseUrl}/#{thingType}?id=#{id}", (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Deleting #{thingType} #{id} done.")
    cb()

createGames = (baseUrl, gameFiles, cb) ->
  doneCount = 0
  for gameFile in gameFiles
    createGame baseUrl, gameFile, ->
      if ++doneCount == gameFiles.length then cb()

createGame = (baseUrl, gameFile, cb) ->
  gameJson = fs.readFileSync(gameFile, { encoding: "utf8"})
  game = JSON.parse(gameJson)

  # Encode certain properties as JSON
  for property in ['processors', 'switches', 'transformers', 'circuits', 'assets']
    game[property] = JSON.stringify(game[property], null, 2)

  requestOptions = 
    url:  "#{baseUrl}/games"
    json: game
  request.post requestOptions, (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Creating game #{gameFile} done.")

    # Create game version
    game.gameId = body.id
    requestOptions = 
      url:  "#{baseUrl}/game-versions"
      json: game
    request.post requestOptions, (error, response, body) ->
      if error then return console.error(error)
      if statusIsError(response.statusCode) then return console.error(body)
      
      console.log("Creating game version #{gameFile} done.")
      cb()

getAllGameVersions = (baseUrl, gameId, cb) ->
  request "#{baseUrl}/game-versions?gameId=#{gameId}", (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    gameVersions = JSON.parse(body)
    console.log("Found #{gameVersions.length} game versions.")
    cb(gameVersions)


# Define command-line arguments
program
  .option('-b, --baseUrl <url>', 'Base URL of RedMetrics server. Include protocol, host and port (ex. http://localhost:5000). Defaults to http://api.redwire.io', 'http://redwire.io/api')
  .option('-u, --user <user>', 'User name (must be an admin)')
  .option('-p, --password <password>', 'Password')

program
  .command('import <games...>')
  .description('Import one or more games from JSON files')
  .action (gameFiles, options) -> 
    login program.baseUrl, program.user, program.password, ->
      createGames program.baseUrl, gameFiles, ->
        console.log("Success!")

program
  .command('exportGame <gameId> <outputFile>')
  .description('Export all the versions of a game into a single JSON file')
  .action (gameId, outputFile, options) -> 
    console.log("Exporting game #{gameId}...")
    login program.baseUrl, program.user, program.password, ->
      getAllGameVersions program.baseUrl, gameId, (gameVersions) ->
        fs.writeFileSync(outputFile, JSON.stringify(gameVersions), { encoding: "utf8"})
        console.log("Wrote to #{outputFile}")

program
  .command('deleteAllGames')
  .description("Delete all games")
  .action (options) -> 
    console.log("Deleting all games")
    login program.baseUrl, program.user, program.password, ->
      deleteAllThings program.baseUrl, "game-versions", ->
        deleteAllThings program.baseUrl, "games", ->
          console.log("Success!")

program.parse(process.argv)

if process.argv.length < 3
  program.help()
