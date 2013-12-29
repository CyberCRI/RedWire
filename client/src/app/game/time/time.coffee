angular.module('gamEvolve.game.time', [])
.controller 'TimeCtrl', ($scope, gameHistory) ->
  $scope.currentFrame = 0
  $scope.lastFrame = 100
  $scope.isPlaying = false

  $scope.jumpToStart = -> $scope.currentFrame = 0
  $scope.jumpToEnd = -> $scope.currentFrame = $scope.lastFrame
  $scope.stepForward = -> if $scope.currentFrame < $scope.lastFrame then $scope.currentFrame++
  $scope.stepBackward = -> if $scope.currentFrame > 0 then $scope.currentFrame--
  $scope.triggerPlay = -> $scope.isPlaying = !$scope.isPlaying

  onUpdateGameHistory = (newGameHistory) ->
    $scope.currentFrame = newGameHistory.currentFrameNumber
    $scope.lastFrame = Math.max(0, newGameHistory.frames.length - 1)

  # Bring gameHistory into the scope in order to watch it
  $scope.gameHistory = gameHistory
  $scope.$watch("gameHistory", onUpdateGameHistory, true)
  onUpdateGameHistory(gameHistory)
