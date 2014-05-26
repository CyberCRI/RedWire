
angular.module('gamEvolve.game.board.editEmitterDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardEmitterDialogCtrl', ($scope, liaison, currentGame) ->
  $scope.DESTINATIONS = currentGame.enumeratePinDestinations()

  $scope.exchange = {}
  $scope.exchange.childName = if liaison.model.name? then JSON.stringify(liaison.model.name) else ""
  $scope.exchange.name = liaison.model.comment
  # Convert between 'pinDef form' used in game serialization and 'pin form' used in GUI
  $scope.exchange.pins = ({ input: input, output: output } for output, input of liaison.model.emitter)

  $scope.addPin = -> $scope.exchange.pins.push({ input: '', output: '' })
  $scope.removePin = (index) -> $scope.exchange.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.exchange.name
    name: if $scope.exchange.childName then JSON.parse($scope.exchange.childName) else null 
    emitter: _.object(([output, input] for {input: input, output: output} in $scope.exchange.pins))
  $scope.cancel = -> liaison.cancel()