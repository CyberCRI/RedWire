angular.module('gamEvolve.game.time', [])
.controller 'TimeCtrl', ($scope, $timeout, gameHistory, gameTime) ->
  $scope.currentFrame = 0
  $scope.currentFrameString = "0" # Needed by the input range element in the template
  $scope.lastFrame = 100
  $scope.isPlaying = false
  $scope.isRecording = false

  $scope.jumpToStart = -> $scope.currentFrame = 0
  $scope.jumpToEnd = -> $scope.currentFrame = $scope.lastFrame
  $scope.stepForward = -> if $scope.currentFrame < $scope.lastFrame then $scope.currentFrame++
  $scope.stepBackward = -> if $scope.currentFrame > 0 then $scope.currentFrame--
  $scope.triggerPlay = -> $scope.isPlaying = !$scope.isPlaying
  $scope.triggerRecord = -> $scope.isRecording = !$scope.isRecording

  onUpdateModel = ->
    $scope.currentFrame = gameTime.currentFrameNumber
    $scope.lastFrame = Math.max(0, gameHistory.data.frames.length - 1)

  onPlayFrame = ->
    if not $scope.isPlaying then return

    if $scope.currentFrame < $scope.lastFrame 
      $scope.currentFrame++
      $timeout(onPlayFrame, 1/60)
    else
      $scope.isPlaying = false

  $scope.$watch("isPlaying", (isPlaying) -> if isPlaying then onPlayFrame())

  $scope.$watch("currentFrame", -> $scope.currentFrameString = $scope.currentFrame.toString())
  $scope.$watch("currentFrameString", -> $scope.currentFrame = parseInt($scope.currentFrameString))

  # Bring gameTime into the scope in order to watch it
  $scope.gameTime = gameTime
  $scope.$watch("gameTime", onUpdateModel, true)

  # Bring gameHistory into the scope in order to watch it
  $scope.gameHistoryMeta = gameHistory.meta
  $scope.$watch("gameHistoryMeta", onUpdateModel, true)
  onUpdateModel()

  # Copy certain attributes back to the service
  $scope.$watch "isRecording", (isRecording) -> gameTime.isRecording = isRecording
  $scope.$watch("currentFrame", (currentFrame) -> gameTime.currentFrameNumber = currentFrame)

