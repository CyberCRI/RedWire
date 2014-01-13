angular.module('gamEvolve.game.time', [])
.controller 'TimeCtrl', ($scope, $timeout, gameHistory) ->
  $scope.currentFrame = 0
  $scope.lastFrame = 100
  $scope.isPlaying = false
  $scope.isRecording = false

  $scope.jumpToStart = -> $scope.currentFrame = 0
  $scope.jumpToEnd = -> $scope.currentFrame = $scope.lastFrame
  $scope.stepForward = -> if $scope.currentFrame < $scope.lastFrame then $scope.currentFrame++
  $scope.stepBackward = -> if $scope.currentFrame > 0 then $scope.currentFrame--
  $scope.triggerPlay = -> $scope.isPlaying = !$scope.isPlaying
  $scope.triggerRecord = -> $scope.isRecording = !$scope.isRecording

  onUpdateGameHistory = (newGameHistory) ->
    $scope.currentFrame = newGameHistory.currentFrameNumber
    $scope.lastFrame = Math.max(0, newGameHistory.frames.length - 1)

  onPlayFrame = ->
    if not $scope.isPlaying then return

    if $scope.currentFrame < $scope.lastFrame 
      $scope.currentFrame++
      $timeout(onPlayFrame, 1/60)
    else
      $scope.isPlaying = false

  $scope.$watch("isPlaying", (isPlaying) -> if isPlaying then onPlayFrame())

  # Bring gameHistory into the scope in order to watch it
  $scope.gameHistory = gameHistory
  $scope.$watch("gameHistory", onUpdateGameHistory, true)
  onUpdateGameHistory(gameHistory)

  # Copy certain attributes back to the service
  $scope.$watch("isRecording", (isRecording) -> gameHistory.isRecording = isRecording)
  $scope.$watch("currentFrame", (currentFrame) -> gameHistory.currentFrameNumber = currentFrame)

