
angular.module('gamEvolve.game.board.editSplitterDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardSplitterDialogCtrl', ($scope, liaison, currentGame) ->
  $scope.DESTINATIONS = currentGame.enumeratePinDestinations()
  $scope.name = liaison.model.comment
  $scope.childName = if liaison.model.name? then JSON.stringify(liaison.model.name) else ""
  $scope.from = liaison.model.splitter.from
  $scope.bindTo = liaison.model.splitter.bindTo
  $scope.index = liaison.model.splitter.index
  $scope.where = liaison.model.splitter.where

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.name
    name: if $scope.childName then JSON.parse($scope.childName) else null 
    splitter:
      from: $scope.from
      bindTo: $scope.bindTo
      index: $scope.index
      where: $scope.where
  $scope.cancel = -> liaison.cancel()
