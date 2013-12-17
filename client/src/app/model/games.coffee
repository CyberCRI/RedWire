angular.module('gamEvolve.model.games', [])

.factory 'currentGame', ->

    info: null

    version: null


.factory 'games', ($http, $q, loggedUser, currentGame) ->

    saveInfo = ->
      $http.post('/games', currentGame.info)
        .then (savedGame) ->
          currentGame.info = savedGame.data
          currentGame.version.gameId = currentGame.info.id

    saveVersion = ->
      delete currentGame.version.id # Make sure a new 'game-version' entity is created
      $http.post('/game-versions', currentGame.version)
        .then (savedGameVersion) -> currentGame.version = savedGameVersion.data


    saveActions:

      none:
        name: 'No Action'
        execute: -> console.log 'games.saveActions.none executed'

      createFromScratch:
        name: 'Create'
        execute: -> saveInfo().then(saveVersion)

      saveNewVersion:
        name: 'Save'
        execute: -> saveVersion()

      fork:
        name: 'Fork'
        execute: ->
          delete currentGame.info.id
          saveInfo().then(saveVersion)


    propertyNames: [
      'actions'
      'assets'
      'layout'
      'model'
      'processes'
      'services'
      'tools'
    ]

    loadJson: (gameName) ->
      deferred = $q.defer()
      promise = deferred.promise
      propertyNames = @propertyNames
      $http.get("/assets/games/#{gameName}.json")
        .error((error) ->
            # TODO Where does this line go ? showMessage(MessageType.Error, "Cannot load game files")
            deferred.reject error
          )
        .success((game) ->
            for propertyName in propertyNames
              game[propertyName] = JSON.stringify(game[propertyName], null, 2)
            currentGame.info = game
            currentGame.version = game
            deferred.resolve game
          )
      promise

    saveCurrent: ->
      @getSaveAction().execute()

    getSaveAction: ->
      unless currentGame.info and currentGame.version and loggedUser.isLoggedIn()
        return @saveActions.none
      if currentGame.info.id and currentGame.info.ownerId is loggedUser.profile.id
        return @saveActions.saveNewVersion
      else if currentGame.info.ownerId
        return @saveActions.fork
      else
        return @saveActions.createFromScratch

    loadAll: ->
      allGames = []
      $http.get('/games')
        .error( (error) -> console.log error )
        .success( (result) -> allGames.push game for game in result )
      allGames

    load: (game) ->
      $http.get('/game-versions?gameId=' + game.id)
        .error( (error) -> console.log error )
        .success( (result) ->
          currentGame.info = game
          currentGame.version = result[0]
        )