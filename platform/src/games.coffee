
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
    dpd.games.post game, callback

  save: (game, callback) ->
    dpd.games.put game, callback

  share: (game) ->
    alert("games.share() called : #{JSON.stringify(game)}")