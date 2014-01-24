#!/usr/bin/env coffee

# IMPORTS 
_ = require("underscore")
fs = require("fs.extra")
path = require("path")
util = require("util")
request = require("request")


# FUNCTIONS
statusIsError = (code) -> String(code)[0] == "4"

login = (callback) ->
  requestOptions = 
    url: "#{server}/users/login"
    json: 
      username: username
      password: password
  request.post requestOptions, (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Logged in")
    callback()

deleteAllThings = (thingType) ->
  request "#{server}/#{thingType}", (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    things = JSON.parse(body)
    console.log("Deleting #{things.length} #{thingType}...")
    for thing in things
      deleteThing(thingType, thing.id)

deleteThing = (thingType, id) ->
  request.del "#{server}/#{thingType}?id=#{id}", (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Deleting #{thingType} #{id} done.")

createGames = ->
  gameFiles = fs.readdirSync(gameDir)
  console.log("Found games", gameFiles)

  for gameFile in gameFiles
    createGame(gameFile)

createGame = (gameFile) ->
  gameJson = fs.readFileSync(path.join(gameDir, gameFile), { encoding: "utf8"})
  game = JSON.parse(gameJson)
  for property in ['actions', 'assets', 'layout', 'model', 'processes', 'services', 'tools']
    game[property] = JSON.stringify(game[property], null, 2)

  requestOptions = 
    url:  "#{server}/games"
    json: game
  request.post requestOptions, (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Creating game #{gameFile} done.")

    # Create game version
    game.gameId = body.id
    requestOptions = 
      url:  "#{server}/game-versions"
      json: game
    request.post requestOptions, (error, response, body) ->
      if error then return console.error(error)
      console.log("Creating game version #{gameFile} done.")


# MAIN
if process.argv.length < 6
  util.error("Usage: coffee reset_db.coffee <server_url> <username> <password> <games_directory>")
  process.exit(1)

[server, username, password, gameDir] = process.argv[2..]

# Have request store and send cookies
request = request.defaults
  jar: true

login ->
  deleteAllThings("game-versions")
  deleteAllThings("games")
  createGames()
