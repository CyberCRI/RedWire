angular.module('gamEvolve.game.undo', ['gamEvolve.model.undo'])
.controller "UndoCtrl", ($scope, undo, currentGame) -> 
  # Bring canUndo() and canRedo() into scope
  $scope.canUndo = undo.canUndo
  $scope.canRedo = undo.canUndo

  $scope.undo = -> 
    if not undo.canUndo() then return 

    currentGame = undo.undo()
    currentLocalVersion = currentGame.localVersion

  $scope.redo = -> 
    if not undo.canRedo() then return 

    currentGame = undo.redo()
    currentLocalVersion = currentGame.localVersion

  currentLocalVersion = 0
  onUpdateCurrentGame = ->
    # Check that this service didn't create the notification
    if currentLocalVersion isnt currentGame.localVersion 
      # Store the change in the undo stack
      # TODO: store diffs to save space?
      undo.changeValue(currentGame)


  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", onUpdateCurrentGame, true)
