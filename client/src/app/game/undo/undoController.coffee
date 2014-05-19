formatDate = ->
  d = new Date()
  return "#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}"

# Saves code to LocalStorage
saveCodeToCache = (programId, data) -> localStorage.setItem(programId, JSON.stringify(data))

# Returns code from LocalStorage or NULL
loadCodeFromCache = (programId) -> return JSON.parse(localStorage.getItem(programId))

# Remove code in LocalStorage
clearCodeInCache = (programId) -> localStorage.removeItem(programId)


angular.module('gamEvolve.game.undo', ['gamEvolve.model.undo'])
.controller "UndoCtrl", ($scope, undo, currentGame) -> 
  currentLocalVersion = 0

  # Bring canUndo() and canRedo() into scope
  $scope.canUndo = -> undo.canUndo()
  $scope.canRedo = -> undo.canRedo()
  $scope.text = "" 

  $scope.undo = -> 
    if not undo.canUndo() then return 

    [currentGame.localVersion, currentGame.version] = undo.undo()
    currentLocalVersion = currentGame.localVersion

  $scope.redo = -> 
    if not undo.canRedo() then return 

    [currentGame.localVersion, currentGame.version] = undo.redo()
    currentLocalVersion = currentGame.localVersion

  onUpdateCurrentGame = ->
    if not currentGame.version then return 

    # Check if this the first time the code is load
    if not currentLocalVersion
      # Check if code exists in offline cache
      cachedCode = loadCodeFromCache(currentGame.info.id)
      if cachedCode and not _.isEqual(currentGame.version, cachedCode)
        if window.confirm("You have some changes saved offline. Restore your offline version?")
          currentGame.version = cachedCode
          currentGame.updateLocalVersion()

    # Check that this service didn't create the notification
    if currentLocalVersion isnt currentGame.localVersion 
      # Store the change in the undo stack
      undo.changeValue(currentGame.localVersion, currentGame.version)
      currentLocalVersion = currentGame.localVersion
      saveCodeToCache(currentGame.info.id, currentGame.version)
      $scope.text = "Saved at #{formatDate()}"

  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", onUpdateCurrentGame, true)

