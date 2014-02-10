
# For accessing a chip within a board via it's path
# Takes the board object and the "path" as an array
# Returns [parent, key] where parent is the parent chip and key is last one required to access the child
getBoardParentAndKey = (parent, pathParts) ->
  if pathParts.length is 0 then return [parent, null]
  if pathParts.length is 1 then return [parent, pathParts[0]]
  if pathParts[0] < parent.children.length then return getBoardParentAndKey(parent.children[pathParts[0]], _.rest(pathParts))
  throw new Error("Cannot find intermediate key '#{pathParts[0]}'")

getBoardChip = (parent, pathParts) ->
  if pathParts.length is 0 then return parent
  [foundParent, index] = getBoardParentAndKey(parent, pathParts)
  return foundParent.children[index]
  

angular.module('gamEvolve.model.games', [])

.factory 'currentGame', ->
  info: null
  version: null
  creator: null
  getTreeNode: (path) ->
    getBoardChip(@version.board, path)

.factory 'games', ($http, $q, loggedUser, currentGame, gameConverter) ->
  saveInfo = ->
    $http.post('/games', currentGame.info)
      .then (savedGame) ->
        currentGame.info = savedGame.data
        currentGame.version.gameId = currentGame.info.id

  updateInfo = ->
    $http.put('/games', currentGame.info)
    
  saveVersion = ->
    delete currentGame.version.id # Make sure a new 'game-version' entity is created
    $http.post('/game-versions', gameConverter.convertGameVersionToEmbeddedJson(currentGame.version))
      .then (savedGameVersion) -> currentGame.version = gameConverter.convertGameVersionFromEmbeddedJson(savedGameVersion.data)

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

  # Load the game content and the creator info, then put it all into currentGame
  load: (game) ->
    # TODO Optimize - Query for the last version only
    getVersion = $http.get('/game-versions?gameId=' + game.id)
    getCreator = $http.get("/users?id=#{game.ownerId}")
    updateCurrentGame = ([version, creator]) ->
      currentGame.info = game
      currentGame.version = gameConverter.convertGameVersionFromEmbeddedJson(version.data[version.data.length-1])
      currentGame.creator = creator.data.username
      console.log("loaded game", currentGame)
    onError = (error) -> console.log("Error loading game", error) # TODO: notify the user of the error
    $q.all([getVersion, getCreator]).then(updateCurrentGame, onError)
