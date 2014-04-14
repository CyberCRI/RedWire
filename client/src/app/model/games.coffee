
angular.module('gamEvolve.model.games', [])


.factory 'currentGame', ->
  info: null
  version: null
  creator: null
  localVersion: 0

  updateLocalVersion: -> @localVersion++

  enumeratePinDestinations: ->
    destinations = @enumerateMemoryKeys(@version.memory)
    @enumerateIoKeys(RW.io, destinations)
    return destinations

  enumerateMemoryKeys: (memory, prefix = ['memory'], keys = []) ->
    for name, value of memory
      keys.push(RW.appendToArray(prefix, name).join('.'))
      if RW.isOnlyObject(value) then @enumerateMemoryKeys(value, RW.appendToArray(prefix, name), keys)
    return keys

  enumerateIoKeys: (ioServices,  keys = []) ->
    # TODO: dig down a bit into what values the io provides
    for name of ioServices
      keys.push(['io', name].join('.'))
    return keys


.factory 'games', ($http, $q, $location, loggedUser, currentGame, gameConverter, gameHistory, gameTime, undo) ->

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
      .then (savedGameVersion) -> currentGame.version = gameConverter.convertGameVersionFromEmbeddedJson(savedGameVersion.data)

  saveActions:
    none:
      name: 'No Action'
      execute: -> console.log 'games.saveActions.none executed'
    saveNewVersion:
      name: 'Save'
      execute: -> updateInfo().then(saveVersion)
    fork:
      name: 'Fork'
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
      return @saveActions.none
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
    gameHistory.reset()
    gameTime.reset()
    undo.reset()

    query = '{"gameId":"' + game.id + '","$sort":{"versionNumber":-1},"$limit":1}'
    getVersion = $http.get("/game-versions?#{query}")
    getCreator = $http.get("/users?id=#{game.ownerId}")
    updateCurrentGame = ([version, creator]) ->
      currentGame.info = game
      currentGame.version = gameConverter.convertGameVersionFromEmbeddedJson(version.data[0])
      currentGame.updateLocalVersion()
      currentGame.creator = creator.data.username
    onError = (error) -> console.log("Error loading game", error) # TODO: notify the user of the error
    $q.all([getVersion, getCreator]).then(updateCurrentGame, onError)

  loadFromId: (gameId) ->
    $http.get("/games/#{gameId}")
      .success(@load)
      .error (error) ->
        console.log error
        window.alert "Hmmm, that game doesn't seem to exist"
        $location.path("/")
