
angular.module('gamEvolve.game.board.editEmitterDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardEmitterDialogCtrl', ($scope, liaison, currentGame) ->
  $scope.DESTINATIONS = currentGame.enumeratePinDestinations()
  $scope.childName = JSON.stringify(liaison.model.name)
  $scope.name = liaison.model.comment
  # Convert between 'pinDef form' used in game serialization and 'pin form' used in GUI
  $scope.pins = ({ input: input, output: output } for output, input of liaison.model.emitter)

  $scope.addPin = -> $scope.pins.push({ input: '', output: '' })
  $scope.removePin = (index) -> $scope.pins.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.name
    name: JSON.parse($scope.childName)
    emitter: _.object(([output, input] for {input: input, output: output} in $scope.pins))
  $scope.cancel = -> liaison.cancel()