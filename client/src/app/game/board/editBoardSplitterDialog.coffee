valueOrNull = (value) -> if value then value else null 

angular.module('gamEvolve.game.board.editSplitterDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardSplitterDialogCtrl', ($scope, liaison, currentGame, pins) ->
  $scope.DESTINATIONS = pins.enumeratePinDestinations()

  $scope.exchange = {}
  $scope.exchange.name = liaison.model.comment
  $scope.exchange.childName = if liaison.model.name? then JSON.stringify(liaison.model.name) else ""
  $scope.exchange.from = liaison.model.splitter.from
  $scope.exchange.bindTo = liaison.model.splitter.bindTo
  $scope.exchange.index = liaison.model.splitter.index
  $scope.exchange.where = liaison.model.splitter.where

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.exchange.name
    name: if $scope.exchange.childName then JSON.parse($scope.exchange.childName) else null 
    splitter:
      from: $scope.exchange.from
      bindTo: $scope.exchange.bindTo
      index: valueOrNull($scope.exchange.index)
      where: valueOrNull($scope.exchange.where)
  $scope.cancel = -> liaison.cancel()
