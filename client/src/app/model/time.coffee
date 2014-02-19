angular.module('gamEvolve.model.time', [])
.factory 'gameTime', ->
  currentFrameNumber: 0
  isRecording: false

  reset: ->
    @currentFrameNumber = 0
    @isRecording = false
