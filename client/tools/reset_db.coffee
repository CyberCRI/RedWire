#!/usr/bin/env coffee

# IMPORTS 
_ = require("underscore")
fs = require("fs.extra")
mime = require("mime")
path = require("path")
util = require("util")
request = require("request")

statusIsError = (code) -> String(code)[0] == "4"

login = (callback) ->
  requestOptions = 
    url: "#{server}/users/login"
    json: 
      username: "micouz"
      password: "password"
  request.post requestOptions, (error, response, body) ->
    if error then return console.error(error)
    if statusIsError(response.statusCode) then return console.error(body)

    console.log("Logged in")
    callback()

deleteAllGames = ->
  request "#{server}/games", (error, response, body) ->
    if error then return console.error(error)

    games = JSON.parse(body)
    for game in games
      deleteGame(game.id)

createGames = ->
  gameFiles = fs.readdirSync(gameDir)
  console.log("Found games", gameFiles)

  for gameFile in gameFiles
    do (gameFile) ->
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

        console.log("Create game #{gameFile} done.")

        # Create game version
        game.gameId = body.id
        requestOptions = 
          url:  "#{server}/game-versions"
          json: game
        request.post requestOptions, (error, response, body) ->
          if error then return console.error(error)
          console.log("Create game version #{gameFile} done.")

# Have request store and send cookies
request = request.defaults
  jar: true

server = "http://cybermongo.unige.ch"
gameDir = "games"

login(createGames)



###
loadGameFromJson = (gameName, callback) ->
  ajaxRequest = $.ajax
    url: "/assets/games/#{gameName}.json"
    dataType: 'json'
    cache: false
  ajaxRequest.fail ->
    console.log "Cannot load game #{gameName} from json"
  ajaxRequest.done (gameJson) ->
    stringify = (propertyName) ->
      gameJson[propertyName] = JSON.stringify(gameJson[propertyName], null, 2)
    stringify('actions')
    stringify('assets')
    stringify('layout')
    stringify('model')
    stringify('processes')
    stringify('services')
    stringify('tools')
    callback gameJson

@.admin =

  deleteAllGames: ->
    # Delete Game Versions
    dpd.gameversions.get (result, error) ->
      return console.log(error) if error
      for gameVersion in result
        dpd.gameversions.del gameVersion.id, (error) ->
          console.log error if error
    # Delete Games
    dpd.games.get (result, error) ->
      return console.log(error) if error
      for game in result
        dpd.games.del game.id, (error) ->
          console.log error if error

  createCoreGames: ->
    gameNames = ['leap', 'optics', 'particle']
    for gameName in gameNames
      loadGameFromJson gameName, (json, error) ->
        if error
          console.log error
        dpd.games.post json, (game, error) ->
          if error
            console.log error
          gameVersion = json
          gameVersion.gameId = game.id
          dpd.gameversions.post gameVersion, (result, error) ->
            if error
              console.log error
###
