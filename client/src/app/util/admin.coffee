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