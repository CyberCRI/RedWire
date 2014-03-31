
angular.module('gamEvolve.game.board.editSplitterDialog', [
  'ui.bootstrap',
])

.controller 'EditBoardSplitterDialogCtrl', ($scope, liaison, currentGame) ->
  $scope.DESTINATIONS = currentGame.enumeratePinDestinations()
  $scope.name = liaison.model.comment
  $scope.childName = liaison.model.name
  $scope.from = liaison.model.splitter.from
  $scope.bindTo = liaison.model.splitter.bindTo
  $scope.index = liaison.model.splitter.index

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.name
    name: $scope.childName
    splitter:
      from: $scope.from
      bindTo: $scope.bindTo
      index: $scope.index
  $scope.cancel = -> liaison.cancel()
