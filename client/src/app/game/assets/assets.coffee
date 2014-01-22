angular.module('gamEvolve.game.assets', [
  'ui.bootstrap',
])
.controller 'AssetsCtrl', ($scope, currentGame) ->
  # Get the actions object from the currentGame service, and keep it updated
  $scope.assets = {}
  $scope.assetNames = []

  # Bring currentGame into scope so we can watch it 
  updateAssets = ->
    if currentGame.version?.actions?
      $scope.assets = currentGame.version.assets
      $scope.assetNames = _.keys(currentGame.version.assets)
  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateAssets, true)

  $scope.remove = (name) -> delete currentGame.version.assets[name]
