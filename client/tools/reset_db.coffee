#!/usr/bin/env coffee

# IMPORTS 
_ = require("underscore")
fs = require("fs.extra")
path = require("path")
util = require("util")
request = require("request")


# FUNCTIONS
statusIsError = (code) -> String(code)[0] == "4"

login = (cb) ->
  requestOptions = 
    url: "#{server}/users/login"
    json: 
      username: username
      password: password
  request.post requestOptions, (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Logged in")
    cb()

deleteAllThings = (thingType, cb) ->
  request "#{server}/#{thingType}", (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    things = JSON.parse(body)
    console.log("Deleting #{things.length} #{thingType}...")
    if things.length is 0 then cb()

    doneCount = 0
    for thing in things
      deleteThing thingType, thing.id, ->
        if ++doneCount == things.length then cb()

deleteThing = (thingType, id, cb) ->
  request.del "#{server}/#{thingType}?id=#{id}", (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Deleting #{thingType} #{id} done.")
    cb()

createGames = (cb) ->
  doneCount = 0
  for gameFile in gameFiles
    createGame gameFile, ->
      if ++doneCount == gameFiles.length then cb()

createGame = (gameFile, cb) ->
  gameJson = fs.readFileSync(gameFile, { encoding: "utf8"})
  game = JSON.parse(gameJson)
  # Encode circuits as JSON
  game.circuits = JSON.stringify(game.circuits, null, 2)

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
      if statusIsError(response.statusCode) then return console.error(body)
      
      console.log("Creating game version #{gameFile} done.")
      cb()


# MAIN
if process.argv.length < 6
  util.error("Usage: coffee reset_db.coffee <server_url> <username> <password> <games_files...>")
  process.exit(1)

[server, username, password, gameFiles...] = process.argv[2..]

# Have request store and send cookies
request = request.defaults
  jar: true

login ->
  deleteAllThings "game-versions", ->
    deleteAllThings "games", ->
      createGames ->
        console.log("Success!")
