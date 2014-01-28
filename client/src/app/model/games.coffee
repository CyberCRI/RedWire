# These properties need to be converted from JSON strings to objects upon loading, and back to JSON for saving
JSON_PROPERTIES = [
  'processors'
  'assets'
  'board'
  'memory'
  'switches'
  'io'
  'transformers'
]

convertGameVersionFromJson = (gameVersionJson) ->
  gameVersion = 
    id: gameVersionJson.id
    gameId: gameVersionJson.gameId
    versionNumber: gameVersionJson.versionNumber
  for propertyName in JSON_PROPERTIES
    gameVersion[propertyName] = JSON.parse(gameVersionJson[propertyName])
  return gameVersion

convertGameVersionToJson = (gameVersion) ->
  gameVersionJson = 
    id: gameVersion.id
    gameId: gameVersion.gameId
    versionNumber: gameVersion.versionNumber
  for propertyName in JSON_PROPERTIES
    gameVersionJson[propertyName] = JSON.stringify(gameVersion[propertyName], null, 2)
  return gameVersionJson


angular.module('gamEvolve.model.games', [])

.factory 'currentGame', ->
  info: null
  version: null
  creator: null

.factory 'games', ($http, $q, loggedUser, currentGame) ->
  saveInfo = ->
    $http.post('/games', currentGame.info)
      .then (savedGame) ->
        currentGame.info = savedGame.data
        currentGame.version.gameId = currentGame.info.id

  updateInfo = ->
    $http.put('/games', currentGame.info)
    
  saveVersion = ->
    delete currentGame.version.id # Make sure a new 'game-version' entity is created
    $http.post('/game-versions', convertGameVersionToJson(currentGame.version))
      .then (savedGameVersion) -> currentGame.version = convertGameVersionFromJson(savedGameVersion.data)

  # TODO: shouldn't this just define an object rather than returning an object? What's the role of the names?
  saveActions:
    none:
      name: 'No Action'
      execute: -> console.log 'games.saveActions.none executed'
    createFromScratch:
      name: 'Create'
      execute: -> saveInfo().then(saveVersion)
    saveNewVersion:
      name: 'Save'
      execute: -> updateInfo().then(saveVersion)
    fork:
      name: 'Fork'
      execute: ->
        delete currentGame.info.id
        saveInfo().then(saveVersion)

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
    # Load the game content and the creator info, then put it all into currentGame
    getVersion = $http.get('/game-versions?gameId=' + game.id)
    getCreator = $http.get("/users?id=#{game.ownerId}")
    updateCurrentGame = ([version, creator]) ->
      currentGame.info = game
      currentGame.version = convertGameVersionFromJson(version.data[0])
      currentGame.creator = creator.data.username
      console.log("loaded game", currentGame)
    onError = (error) -> console.log("Error loading game", error) # TODO: notify the user of the error

    $q.all([getVersion, getCreator]).then(updateCurrentGame, onError)
