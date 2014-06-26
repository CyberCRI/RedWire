angular.module('gamEvolve.game.toolbox.transformers', [
  'ui.bootstrap',
])
.controller 'EditTransformerDialogCtrl', ($scope, liaison) ->
  # Need to put 2-way data binding under an object
  $scope.exchange = {}
  $scope.exchange.name = liaison.model.name
  $scope.exchange.arguments = for argument in liaison.model.arguments 
    { value: argument } 
  $scope.exchange.body = liaison.model.body

  $scope.addArgument = -> $scope.exchange.arguments.push({ value: "" })
  $scope.removeArgument = (index) -> $scope.exchange.arguments.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done 
    name: $scope.exchange.name
    arguments: for argument in $scope.exchange.arguments
      argument.value
    body: $scope.exchange.body
  $scope.cancel = -> liaison.cancel() 
