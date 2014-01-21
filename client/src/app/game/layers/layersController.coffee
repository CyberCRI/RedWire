angular.module('gamEvolve.game.layers', [
  'ui.directives',
])
.controller 'LayersCtrl', ($scope, currentGame) ->
  # TODO: create this list dynamically
  $scope.TYPES = [
    "Canvas"
    "HTML"
    "Chart"
  ]

  # Get the actions object from the currentGame service, and keep it updated
  $scope.layers = [
    { name: "bg", type: "Canvas" }
    { name: "pieces", type: "Chart" }
    { name: "fg", type: "HTML" }
  ]

  $scope.addLayer = -> $scope.layers.push({ name: "", type: $scope.TYPES[0] })
  $scope.removeLayer = (index) -> $scope.layers.splice(index, 1)

  # Bring currentGame into scope so we can watch it 
  updateLayers = -> 

  $scope.currentGame = currentGame
  $scope.$watch('currentGame', updateLayers, true)
