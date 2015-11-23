angular.module('gamEvolve.model.games', [])

.factory 'currentGame', (GameVersionUpdatedEvent, WillChangeLocalVersionEvent) ->
  version: null
  setVersion: (newVersion) ->
    @version = newVersion
    GameVersionUpdatedEvent.send(newVersion)
  info: null
  creator: null
  localVersion: _.uniqueId("v")
  windowId: RW.makeGuid() # Used to identify windows across drag and drop
  standardLibrary: null
  hasUnpublishedChanges: false

  statusMessage: ""

  reset: -> 
    @info = null
    @version = null
    @creator = null
    @localVersion = _.uniqueId("v")
    @hasUnpublishedChanges = false

  updateLocalVersion: -> 
    # Give an opportunity to change the game code before it is updated
    WillChangeLocalVersionEvent.send()
    @localVersion = _.uniqueId("v")

  setHasUnpublishedChanges: -> @hasUnpublishedChanges = true
  clearHasUnpublishedChanges: -> @hasUnpublishedChanges = false

  setStatusMessage: (message) -> @statusMessage = message

.factory 'games', ($http, $q, $location, loggedUser, currentGame, gameConverter, gameHistory, gameTime, undo, overlay, GameVersionPublishedEvent, NewGameLoadingEvent) ->

  games = {}
  games.saveInfo = ->
    $http.post('/api/games', currentGame.info)
      .then (savedGame) ->
        currentGame.info = savedGame.data
        currentGame.version.gameId = currentGame.info.id
        $http.get("/api/users?id=#{currentGame.info.ownerId}")
      .then (creator) ->
        currentGame.creator = creator.data.username

  games.updateInfo = ->
    $http.put('/api/games', currentGame.info)
    
  games.saveVersion = ->
    delete currentGame.version.id # Make sure a new 'game-version' entity is created
    $http.post('/api/game-versions', gameConverter.convertGameVersionToEmbeddedJson(currentGame.version))
      .then((savedGameVersion) -> currentGame.setVersion(gameConverter.convertGameVersionFromEmbeddedJson(savedGameVersion.data)))
      .then(-> GameVersionPublishedEvent.send())

  games.clearGameData = -> 
    # Clear the current game data
    # TODO: have each service detect this event rather than hard coding it here?
    NewGameLoadingEvent.send()
    overlay.makeNotification()
    currentGame.reset()
    gameHistory.reset()
    gameTime.reset()
    undo.reset()

  games.publishCurrent = ->
    games.updateInfo().then(games.saveVersion)

  games.forkCurrent = ->
    # Set the old game ID as the parent of the new one. 
    # Then remove the current game ID to make the server provide a new one
    currentGame.info.parentId = currentGame.info.id
    delete currentGame.info.id 

    games.saveInfo().then ->
      $location.path("/game/#{currentGame.version.gameId}/edit")
      games.saveVersion()

  games.deleteCurrent = ->
    $http.delete("/api/games/#{currentGame.version.gameId}").then(currentGame.reset)

  # Load the game content and the creator info, then put it all into currentGame
  games.load = (game) ->
    games.clearGameData()

    query = '{"gameId":"' + game.id + '","$sort":{"versionNumber":-1},"$limit":1}'
    getVersion = $http.get("/api/game-versions?#{query}")
    getCreator = $http.get("/api/users?id=#{game.ownerId}")
    getStandardLibrary = $http.get("/assets/standardLibrary.json")
    updateCurrentGame = ([version, creator, standardLibrary]) ->
      currentGame.info = game

      gameCode = gameConverter.convertGameVersionFromEmbeddedJson(version.data[0])
      gameConverter.bringGameUpToDate(gameCode)
      currentGame.setVersion(gameCode)

      currentGame.standardLibrary = standardLibrary.data
      currentGame.updateLocalVersion()
      currentGame.creator = creator.data.username
    onError = (error) -> 
      console.error("Error loading game", error) 
      window.alert("Error loading game")
    onDone = -> overlay.clearNotification()
    $q.all([getVersion, getCreator, getStandardLibrary]).then(updateCurrentGame, onError).finally(onDone)

  games.loadFromId = (gameId) ->
    $http.get("/api/games/#{gameId}")
      .success(games.load)
      .error (error) ->
        console.log(error)
        window.alert("Hmmm, that game doesn't seem to exist")
        $location.path("/")

  games.recordPlay = (gameId) -> $http.post("/api/play/#{gameId}")

  games.getLikedCount = (gameId) -> $http.get("/api/like/#{gameId}").then((results) -> return results.data)

  games.recordLike = (gameId) -> $http.post("/api/like/#{gameId}")

  games.recordMix = (fromGameId) -> $http.post("/api/mix/from/#{fromGameId}/to/#{currentGame.info.id}")


  # Functions to load lists of games from the server
  games.loadAll = -> return $http.get('/api/games').then((result) -> return result.data).catch(-> alert("Can't load games"))

  games.countGames = (query = {}) ->
    query = _.extend {}, query, 
      id: "count"
    return $http.get("/api/games?#{JSON.stringify(query)}").then((result) -> return result.data.count)

  games.getPageOfGames = (pageNumber, itemsPerPage, query = {}) -> 
    query = _.extend {}, query, 
      $limit: itemsPerPage
      $skip: pageNumber * itemsPerPage 
    return $http.get("/api/games?#{JSON.stringify(query)}").then((result) -> return result.data)

  games.getRecommendations = -> 
    return $http.get('/api/recommend').then (result) -> _.shuffle(result.data)
  
  games.countRecommendations = -> 
    return $http.get('/api/recommend?count=true').then (result) -> result.data.count

  games.getMyGames = -> 
    return $http.get("/api/games?ownerId=#{loggedUser.profile.id}").then((result) -> return result.data)


  return games
