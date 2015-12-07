angular.module('gamEvolve.game.channels', [])

.controller 'ChannelsCtrl', ($scope, currentGame, circuits, dndHelper) ->
  $scope.TYPES = ["clip", "music", "fx"]

  # Get the actions object from the currentGame service, and keep it updated
  $scope.channels = []

  $scope.addChannel = -> $scope.channels.push({ name: "", type: "" })
  $scope.removeChannel = (index) -> 
    $scope.channels.splice(index, 1)
  $scope.cloneChannel = (index) ->
    existingNames = _.pluck($scope.channels, "name")
    newChannel = 
      name: dndHelper.findNewName(existingNames, $scope.channels[index].name)
      type: $scope.channels[index].type
    $scope.channels.splice(index + 1, 0, newChannel)

  # Bring currentGame into scope so we can watch it 
  copyFromGameToScope = ->
    if not currentGame.version then return 
    currentCircuitData = currentGame.version.circuits[circuits.currentCircuitMeta.type]
    $scope.channels = RW.cloneData(currentCircuitData.io.channels)

  $scope.currentGame = currentGame
  $scope.$watch("currentGame.localVersion", copyFromGameToScope, true)
  $scope.$watch((-> circuits.currentCircuitMeta), copyFromGameToScope, true)

  copyFromScopeToGame = ->
    if not currentGame.version then return 
    currentCircuitData = currentGame.version.circuits[circuits.currentCircuitMeta.type]
    if _.isEqual(currentCircuitData.io.channels, $scope.channels) then return 

    currentCircuitData.io.channels = $scope.channels
    currentGame.updateLocalVersion()
  $scope.$watch("channels", copyFromScopeToGame, true)

