valueOrNull = (value) -> if value then value else null 

angular.module('gamEvolve.game.board.editCircuitDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardCircuitDialogCtrl', ($scope, liaison, currentGame) ->
  $scope.DESTINATIONS = currentGame.enumeratePinDestinations()

  $scope.exchange = {}
  $scope.exchange.name = liaison.model.id
  $scope.exchange.childName = if liaison.model.name? then JSON.stringify(liaison.model.name) else ""

  # Reply with the new data
  $scope.done = -> liaison.done
    id: $scope.exchange.name
    name: if $scope.exchange.childName then JSON.parse($scope.exchange.childName) else null 
  $scope.cancel = -> liaison.cancel()
