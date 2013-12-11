@.games =

  lastSavedGame: null
  lastSavedVersion: null

  save: (game, callback) ->
    dpd.users.me (me, error) ->
      if error
        console.log error
      else
        if games.lastSavedGame
          console.log 'Already Saved'
          if me.id is games.lastSavedGame.ownerId
            console.log 'User owns game, save new version'
            gameVersion = games.lastSavedVersion
            delete gameVersion.id
            games.saveVersion gameVersion, callback
          else
            console.log 'User does not own game, fork game'
            gameVersion = game
            game = games.lastSavedGame
            game.parentId = game.id
            delete game.id
            dpd.games.post game, (createdGame, error) ->
              if not error and createdGame?
                games.lastSavedGame = createdGame
                gameVersion.gameId = createdGame.id
                games.saveVersion gameVersion, callback
        else
          console.log 'Game not saved yet, save now with version'
          dpd.games.post game, (savedGame, error) ->
            if error
              callback savedGame, error
            else
              games.lastSavedGame = savedGame
              gameVersion = game
              gameVersion.gameId = savedGame.id
              games.saveVersion gameVersion, callback

  saveVersion: (gameVersion, callback) ->
    dpd.gameversions.post gameVersion, (savedGameVersion, error) ->
      if error
        console.log error
      else
        games.lastSavedVersion = savedGameVersion
      callback?(savedGameVersion, error)

  read: (id, callback) ->
    dpd.games.get id, callback

  update: (game, callback) ->
    dpd.games.put game, callback

  share: (game) ->
    alert("games.share() called : #{JSON.stringify(game)}")