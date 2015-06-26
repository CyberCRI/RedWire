angular.module('gamEvolve.game.edit.header.volume', [])

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