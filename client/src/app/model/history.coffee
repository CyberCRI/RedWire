angular.module('gamEvolve.model.history', [])
.factory 'gameHistory', ->
  currentFrameNumber: 0
  frames: [ ]
