formatDate = ->
  d = new Date()
  return "#{d.getHours()}:#{d.getMinutes()}:#{d.getSeconds()}"

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

    # Check that this service didn't create the notification
    if currentLocalVersion isnt currentGame.localVersion 
      # Store the change in the undo stack
      undo.changeValue(currentGame.localVersion, currentGame.version)
      currentLocalVersion = currentGame.localVersion
      $scope.text = "Saved at #{formatDate()}"

  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", onUpdateCurrentGame, true)
