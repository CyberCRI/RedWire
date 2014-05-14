angular.module('gamEvolve.game.layers', [
  'ui.sortable',
])
.controller 'LayersCtrl', ($scope, currentGame) ->
  $scope.TYPES = (name for name, io of RW.io when io.meta.visual)

  # Get the actions object from the currentGame service, and keep it updated
  $scope.layers = []

  $scope.addLayer = -> currentGame.version.layers.push({ name: "", type: "" })
  $scope.removeLayer = (index) -> 
    if window.confirm("Are you sure you want to delete this layer?")
      currentGame.version.splice(index, 1)
      currentGame.updateLocalVersion()

  # Bring currentGame into scope so we can watch it 
  updateLayers = -> $scope.layers = currentGame.version?.io?.layers

  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", updateLayers, true)
