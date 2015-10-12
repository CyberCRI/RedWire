angular.module('gamEvolve.model.time', [])
.factory 'gameTime', ->
  currentFrameNumber: 0
  isPlaying: false
  inRecordMode: false
  isTakingScreenshots: false

  reset: ->
    @currentFrameNumber = 0
    @isPlaying = false
    @inRecordMode = false
    @isTakingScreenshots = false
