
@.games =

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
    dpd.games.post game, (error, createdGame) ->
      if error or not result
        callback error, result
      else
        gameVersion
        dpd.game-versions.post game, callback

  read: (id, callback) ->
    dpd.games.get id, callback

  update: (game, callback) ->
    dpd.games.put game, callback

  share: (game) ->
    alert("games.share() called : #{JSON.stringify(game)}")