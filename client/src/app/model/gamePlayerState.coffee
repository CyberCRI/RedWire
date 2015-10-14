angular.module('gamEvolve.model.gameplayerstate', [])
.factory 'gamePlayerState', ->
  isMuted: false
  volume: 1

  reset: ->
    @isMuted = false
    @volume = 1
