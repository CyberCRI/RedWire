valueOrNull = (value) -> if value then value else null 

angular.module('gamEvolve.game.board.editPipeDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardPipeDialogCtrl', ($scope, liaison, currentGame, pins) ->
  $scope.DESTINATIONS = pins.enumeratePinDestinations()

  $scope.exchange = {}
  $scope.exchange.name = liaison.model.comment
  $scope.exchange.childName = if liaison.model.name? then JSON.stringify(liaison.model.name) else ""
  $scope.exchange.initialValue = liaison.model.pipe.initialValue
  $scope.exchange.bindTo = liaison.model.pipe.bindTo
  $scope.exchange.outputDestination = liaison.model.pipe.outputDestination

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.exchange.name
    name: if $scope.exchange.childName then JSON.parse($scope.exchange.childName) else null 
    pipe:
      initialValue: $scope.exchange.initialValue
      bindTo: $scope.exchange.bindTo
      outputDestination: valueOrNull($scope.exchange.outputDestination)
  $scope.cancel = -> liaison.cancel()
