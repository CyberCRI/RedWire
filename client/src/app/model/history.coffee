angular.module('gamEvolve.model.history', [])
.factory 'gameHistory', ->
  currentFrameNumber: 0
  isRecording: false
  # TODO: don't store the entire model and serviceData each time! Use patches, or better yet, persistant data structures
  frames: [ ]
