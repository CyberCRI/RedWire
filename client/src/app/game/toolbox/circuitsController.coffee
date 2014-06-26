angular.module('gamEvolve.game.toolbox.circuits', [
  'ui.bootstrap',
])
.controller 'EditCircuitDialogCtrl', ($scope, liaison) ->
  # Need to put 2-way data binding under an object
  $scope.exchange = {}
  $scope.exchange.name = liaison.model.name

  # Reply with the new data
  $scope.done = -> liaison.done 
    name: $scope.exchange.name
  $scope.cancel = -> liaison.cancel() 
