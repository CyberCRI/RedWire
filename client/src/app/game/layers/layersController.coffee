angular.module('gamEvolve.game.layers', [
  'ui.sortable',
])
.controller 'LayersCtrl', ($scope, currentGame) ->
  $scope.TYPES = (name for name, io of RW.io when io.meta.visual)

  # Get the actions object from the currentGame service, and keep it updated
  $scope.layers = []

  $scope.addLayer = -> $scope.layers.push({ name: "", type: "" })
  $scope.removeLayer = (index) -> 
    if window.confirm("Are you sure you want to delete this layer?")
      $scope.layers.splice(index, 1)

  # Bring currentGame into scope so we can watch it 
  updateLayers = -> $scope.layers = currentGame.version?.io?.layers

  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateLayers, true)
