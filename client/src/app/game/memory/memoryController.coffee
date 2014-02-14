WAIT_TIME = 2000

angular.module('gamEvolve.game.memory', [])

.controller 'MemoryCtrl', ($scope, gameHistory, gameTime, currentGame) ->
  $scope.gameHistoryMeta = gameHistory.meta 
  $scope.gameTime = gameTime

  onEditorChange = -> $scope.$apply(onUpdateMemoryEditor)

  editor = new jsoneditor.JSONEditor $("#memoryEditor")[0],
    change: _.debounce(onEditorChange, WAIT_TIME)
    name: "memory"

  # Update from gameHistory
  onUpdateMemoryModel = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    memoryModel = 
      if gameTime.currentFrameNumber is 0
        currentGame.version.memory
      else
        gameHistory.data.frames[gameTime.currentFrameNumber].memory

    if _.isEqual(memoryModel, editor.get()) then return 

    # Clone so that the editor doesn't modify our recorded data directly
    editor.set(GE.cloneData(memoryModel))

  $scope.$watch('gameHistoryMeta', onUpdateMemoryModel, true)
  $scope.$watch('gameTime.currentFrameNumber', onUpdateMemoryModel)

  # Write back to gameHistory
  onUpdateMemoryEditor = ->
    if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return 

    # If we are on the first frame, update the game memory
    if gameTime.currentFrameNumber == 0 
      currentGame.version.memory = GE.cloneData(editor.get())
