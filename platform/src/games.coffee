@.games =

  lastSavedVersion: {}

  loadJson: (gameName, callback) ->
    ajaxRequest = $.ajax
      url: "/json/games/#{gameName}.json"
      dataType: "json"
      cache: false
    ajaxRequest.fail -> showMessage(MessageType.Error, "Cannot load game files")
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

  create: (game, callback) ->
    gameVersion = game
    dpd.games.post game, (createdGame, error) ->
      if not error and createdGame?
        gameVersion.gameId = createdGame.id
        games.saveVersion gameVersion, () ->
          games.saveVersion games.lastSavedVersion
      else
        console.log error
        callback createdGame, error

  saveVersion: (gameVersion, callback) ->
    dpd.gameversions.post gameVersion, (savedGameVersion, error) ->
      if error
        console.log error
      else
        games.lastSavedVersion = gameVersion
      callback?(savedGameVersion, error)

  read: (id, callback) ->
    dpd.games.get id, callback

  update: (game, callback) ->
    dpd.games.put game, callback

  share: (game) ->
    alert("games.share() called : #{JSON.stringify(game)}")