
angular.module('gamEvolve.game.board.editEmitterDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardEmitterDialogCtrl', ($scope, liaison, currentGame, pins) ->
  $scope.exchange = {}
  $scope.exchange.childName = if liaison.model.name? then JSON.stringify(liaison.model.name) else ""
  $scope.exchange.name = liaison.model.comment
  $scope.exchange.expressionText = liaison.model.emitter

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.exchange.name
    name: if $scope.exchange.childName then JSON.parse($scope.exchange.childName) else null 
    emitter: $scope.exchange.expressionText
  $scope.cancel = -> liaison.cancel()