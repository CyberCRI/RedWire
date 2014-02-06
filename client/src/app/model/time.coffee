angular.module('gamEvolve.model.time', [])
.factory 'gameTime', ->
  currentFrameNumber: 0
  isRecording: false
  errorsFound: false

