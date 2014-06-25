angular.module('gamEvolve.game.layers', [])

.controller 'LayersCtrl', ($scope, currentGame, circuits) ->
  $scope.TYPES = (name for name, io of RW.io when io.meta.visual)

  # Get the actions object from the currentGame service, and keep it updated
  $scope.layers = []

  $scope.addLayer = -> $scope.layers.push({ name: "", type: "" })
  $scope.removeLayer = (index) -> 
    if window.confirm("Are you sure you want to delete this layer?")
      $scope.layers.splice(index, 1)

  # Bring currentGame into scope so we can watch it 
  copyFromGameToScope = ->
    if not currentGame.version then return 
    currentCircuitData = currentGame.version.circuits[circuits.currentCircuitMeta.type]
    $scope.layers = RW.cloneData(currentCircuitData.io.layers)

  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", copyFromGameToScope, true)
  $scope.$watch((-> circuits.currentCircuitMeta), copyFromGameToScope, true)

  copyFromScopeToGame = ->
    if not currentGame.version then return 
    currentCircuitData = currentGame.version.circuits[circuits.currentCircuitMeta.type]
    if _.isEqual(currentCircuitData.io.layers, $scope.layers) then return 

    currentCircuitData.io.layers = $scope.layers
    currentGame.updateLocalVersion()
  $scope.$watch("layers", copyFromScopeToGame, true)

