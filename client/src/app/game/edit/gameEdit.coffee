
angular.module('gamEvolve.game.edit', [
  'flexyLayout'
  'gamEvolve.game.edit.header'
])


.config ($stateProvider) ->
  $stateProvider.state 'game-edit',
    url: '/game/:gameId/edit'
    views: 
      "main":
        controller: 'GameEditCtrl'
        templateUrl: 'game/edit/gameEdit.tpl.html'
    data: 
      pageTitle: 'Edit Game'


.controller 'GameEditCtrl', ($scope, $stateParams, games, circuits, currentGame) ->

  games.loadFromId $stateParams.gameId

  # Used by toolbox list
  # TODO: put in own controller
  $scope.isFirstOpen = true

  $scope.getCircuitParts = -> 
    if circuits.currentCircuitMeta.id
      for circuitPart in circuits.currentCircuitMeta.id.split(".") then circuitPart
    else
      ["Circuit: #{circuits.currentCircuitMeta.type}"]

  $scope.switchToMainCircuit = -> circuits.reset()

  $scope.switchCircuit = (index) ->
    # Get intermediate circuit ID
    circuitId = circuits.currentCircuitMeta.id.split(".")[0..index].join(".")

    # Get complete list of circuits
    circuitMetas = RW.listCircuitMeta(currentGame.version.circuits)
    circuitMeta = _.findWhere(circuitMetas, { id: circuitId })

    # Switch current circuit
    circuits.currentCircuitMeta = circuitMeta


.controller 'LogoCtrl', ($scope, aboutDialog) ->
  $scope.aboutDialog = aboutDialog