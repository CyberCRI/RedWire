angular.module('gamEvolve.game.edit.header.time', [])

.controller 'TimeCtrl', ($scope, $timeout, gameHistory, gameTime) ->
  $scope.currentFrame = 0
  $scope.currentFrameString = "0" # Needed by the input range element in the template
  $scope.lastFrame = 100
  $scope.isPlayingBack = false
  $scope.inRecordMode = false
  $scope.isPlaying = false
  $scope.disableTimeControls = true

  $scope.jumpToStart = -> $scope.currentFrame = 0
  $scope.jumpToEnd = -> $scope.currentFrame = $scope.lastFrame
  $scope.stepForward = -> if $scope.currentFrame < $scope.lastFrame then $scope.currentFrame++
  $scope.stepBackward = -> if $scope.currentFrame > 0 then $scope.currentFrame--
  $scope.triggerPlayBack = -> $scope.isPlayingBack = !$scope.isPlayingBack
  $scope.triggerPlay = -> $scope.isPlaying = !$scope.isPlaying

  $scope.reset = -> 
    frameCount = gameHistory.data.frames.length
    if frameCount > 1
      gameHistory.data.frames.splice(1, frameCount - 1)
      gameHistory.meta.version++
      gameTime.currentFrameNumber = 0

  onUpdateModel = ->
    $scope.currentFrame = gameTime.currentFrameNumber
    $scope.lastFrame = Math.max(0, gameHistory.data.frames.length - 1)
    $scope.isPlaying = gameTime.isPlaying
    $scope.disableTimeControls = gameHistory.data.frames.length < 2 or $scope.isPlaying

  onPlayBackFrame = ->
    if not $scope.isPlayingBack then return

    if $scope.currentFrame < $scope.lastFrame 
      $scope.currentFrame++
      $timeout(onPlayBackFrame, 1/60)
    else
      $scope.isPlayingBack = false

  $scope.$watch("isPlayingBack", (isPlayingBack) -> if isPlayingBack then onPlayBackFrame())


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
  $scope.$watch "isPlaying", (isPlaying) -> gameTime.isPlaying = isPlaying
  $scope.$watch "inRecordMode", (inRecordMode) -> gameTime.inRecordMode = inRecordMode
  $scope.$watch("currentFrame", (currentFrame) -> gameTime.currentFrameNumber = currentFrame)





.controller 'VolumeCtrl', ($scope, gamePlayerState) ->
  $scope.isMuted = gamePlayerState.isMuted
  $scope.volume = gamePlayerState.volume
  $scope.baseValue = gamePlayerState.volume*100

  changeVolume = (value) -> 
    gamePlayerState.volume = parseInt(value)/100
    if $scope.isMuted then $scope.triggerMute()

  $scope.triggerMute = -> 
    $scope.isMuted = !$scope.isMuted
    gamePlayerState.isMuted = $scope.isMuted

  $scope.$watch('baseValue', changeVolume, true)
