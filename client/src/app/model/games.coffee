
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

  statusMessage: ""

  reset: -> 
    @info = null
    @version = null
    @creator = null
    @localVersion = _.uniqueId("v")

  updateLocalVersion: -> 
    # Give an opportunity to change the game code before it is updated
    WillChangeLocalVersionEvent.send()
    @localVersion = _.uniqueId("v")

.factory 'games', ($http, $q, $location, loggedUser, currentGame, gameConverter, gameHistory, gameTime, undo, overlay) ->

  saveInfo = ->
    $http.post('/games', currentGame.info)
      .then (savedGame) ->
        currentGame.info = savedGame.data
        currentGame.version.gameId = currentGame.info.id
        $http.get("/users?id=#{currentGame.info.ownerId}")
      .then (creator) ->
        currentGame.creator = creator.data.username

  updateInfo = ->
    $http.put('/games', currentGame.info)
    
  saveVersion = ->
    delete currentGame.version.id # Make sure a new 'game-version' entity is created
    $http.post('/game-versions', gameConverter.convertGameVersionToEmbeddedJson(currentGame.version))
      .then((savedGameVersion) -> currentGame.setVersion(gameConverter.convertGameVersionFromEmbeddedJson(savedGameVersion.data)))
      .then(-> currentGame.statusMessage = "Published at #{moment().format("HH:mm:ss")}")

  saveActions:
    saveNewVersion:
      name: 'Publish'
      classes: "font-icon-upload"
      execute: -> 
        updateInfo().then(saveVersion)
    fork:
      name: 'Fork'
      classes: "font-icon-fork"
      execute: ->
        # Removing the game ID will make the server provide a new one
        delete currentGame.info.id
        saveInfo().then -> 
          $location.path("/game/#{currentGame.version.gameId}/edit")
          saveVersion()

  saveCurrent: ->
    @getSaveAction().execute()

  getSaveAction: ->
    unless currentGame.info and currentGame.version and loggedUser.isLoggedIn()
      return null

    if currentGame.info.id and currentGame.info.ownerId is loggedUser.profile.id
      return @saveActions.saveNewVersion
    else 
      return @saveActions.fork

  loadAll: ->
    gamesQuery = $http.get('/games')
    usersQuery = $http.get("/users") #?{fields={id: 1, username: 1}
    fillGamesList = ([gamesResult, usersResult]) -> 
      for game in gamesResult.data
        id: game.id
        name: game.name
        author: _.findWhere(usersResult.data, { id: game.ownerId }).username
    # This promise will be returned
    $q.all([gamesQuery, usersQuery]).then(fillGamesList, -> alert("Can't load games"))

  # Load the game content and the creator info, then put it all into currentGame
  load: (game) ->
    # Clear the current game data
    # TODO: have each service detect this event rather than hard coding it here?
    overlay.makeNotification()
    currentGame.reset()
    gameHistory.reset()
    gameTime.reset()
    undo.reset()

    query = '{"gameId":"' + game.id + '","$sort":{"versionNumber":-1},"$limit":1}'
    getVersion = $http.get("/game-versions?#{query}")
    getCreator = $http.get("/users?id=#{game.ownerId}")
    updateCurrentGame = ([version, creator]) ->
      currentGame.info = game
      currentGame.setVersion(gameConverter.convertGameVersionFromEmbeddedJson(version.data[0]))
      currentGame.updateLocalVersion()
      currentGame.creator = creator.data.username
    onError = (error) -> 
      console.error("Error loading game", error) 
      window.alert("Error loading game")
    onDone = -> overlay.clearNotification()
    $q.all([getVersion, getCreator]).then(updateCurrentGame, onError).finally(onDone)

  loadFromId: (gameId) ->
    $http.get("/games/#{gameId}")
      .success(@load)
      .error (error) ->
        console.log error
        window.alert "Hmmm, that game doesn't seem to exist"
        $location.path("/")
