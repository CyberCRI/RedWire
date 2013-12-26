angular.module('gamEvolve.game.time', [])
.factory 'gameTime', ->
  currentFrame: 0
  totalFrames: 100
  isPlaying: false
.controller 'TimeCtrl', ($scope, gameTime) ->
  # Bring service into scope, and copy changes back to service
  $scope.gameTime = gameTime 
  $scope.$watch("gameTime", ((newGameTime) -> gameTime = $scope.gameTime), true)

  # Add some helper functions to the scope
  $scope.jumpToStart = -> $scope.gameTime.currentFrame = 0
  $scope.jumpToEnd = -> $scope.gameTime.currentFrame = $scope.gameTime.totalFrames - 1
  $scope.stepForward = -> if $scope.gameTime.currentFrame < $scope.gameTime.totalFrames - 1 then $scope.gameTime.currentFrame++
  $scope.stepBackward = -> if $scope.gameTime.currentFrame > 0 then $scope.gameTime.currentFrame--

  $scope.triggerPlay = -> $scope.gameTime.isPlaying = !$scope.gameTime.isPlaying


