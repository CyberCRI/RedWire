
@.Games =

  current: null

  loadJson: (gameName, callback) ->
    ajaxRequest = $.ajax
      url: "/json/games/#{gameName}.json"
      dataType: "json"
      cache: false
    ajaxRequest.fail -> showMessage(MessageType.Error, "Cannot load game files")
    ajaxRequest.done callback

  save: (game, callback) ->

    stringify = (propertyName) ->
      game[propertyName] = JSON.stringify(game[propertyName], null, 2)

    stringify('model')
    stringify('services')
    stringify('layout')
    stringify('tools')
    stringify('assets')
    dpd.games.post game, callback

  share: (game) ->
    alert("Games.share() called : #{JSON.stringify(game)}")